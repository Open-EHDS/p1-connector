# frozen_string_literal: true

require 'json'

module P1Tool
  module Gateways
    module P1
      class Client
        attr_reader :token

        def initialize(config:, subject:, doctor:, transport: nil, clock: -> { Time.now.utc }, tls_bundle: nil, wss_bundle: nil)
          @config = config
          @subject = subject
          @doctor = doctor
          @clock = clock
          @token = nil
          @tls_bundle = tls_bundle || load_bundle(config.fetch(:certificates).fetch(:tls))
          @wss_bundle = wss_bundle || load_bundle(config.fetch(:certificates).fetch(:wss))
          @transport = transport || build_http_transport
        end

        def create_resource(resource_type:, xml:)
          ensure_access_token!
          response = transport.request(
            method: :post,
            path: "fhir/#{resource_type}",
            headers: xml_headers,
            body: xml
          )
          handle_response!(response, expected_statuses: [201], context: "create #{resource_type}")
          build_resource_response(response)
        end

        def update_resource(resource_type:, reference_id:, xml:)
          ensure_access_token!
          response = transport.request(
            method: :put,
            path: "fhir/#{resource_type}/#{reference_id}",
            headers: xml_headers,
            body: xml
          )
          handle_response!(response, expected_statuses: [200], context: "update #{resource_type} #{reference_id}")
          build_resource_response(response)
        end

        def get_resource(resource_type:, reference_id:)
          ensure_access_token!
          response = transport.request(
            method: :get,
            path: "fhir/#{resource_type}/#{reference_id}",
            headers: token_headers
          )
          handle_response!(response, expected_statuses: [200], context: "get #{resource_type} #{reference_id}")
          { status: response.status, body: parse_body(response.body), headers: response.headers }
        end

        def find_patient(payload:)
          ensure_access_token!
          patient = payload.fetch(:patient)
          response = transport.request(
            method: :get,
            path: 'fhir/Patient',
            headers: token_headers,
            params: {
              plpatient: "#{Constants::PESEL_SYSTEM}|#{patient.fetch(:pesel)}",
              plfamily: patient.fetch(:last_name),
              plgiven: patient.fetch(:first_name).to_s.split.first
            }
          )
          handle_response!(response, expected_statuses: [200], context: 'find patient')
          { status: response.status, body: parse_body(response.body), headers: response.headers }
        end

        private

        attr_reader :config, :subject, :doctor, :clock, :tls_bundle, :wss_bundle, :transport

        def ensure_access_token!
          return token if token

          response = transport.request(
            method: :post,
            path: 'token',
            headers: token_request_headers,
            form: {
              client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
              grant_type: 'client_credentials',
              client_assertion: TokenBuilder.new(subject:, doctor:, clock:).encode(wss_bundle),
              scope: Constants::FHIR_SCOPE
            }
          )
          handle_response!(response, expected_statuses: [200], context: 'access token')
          body = parse_body(response.body)
          @token = body.fetch('accessToken') do
            raise P1Tool::BusinessError, "P1 token response does not include accessToken: #{body.inspect}"
          end
          P1Tool::Runtime::CurrentExecution.record_event(
            event_type: 'p1_access_token_acquired',
            metadata: {
              http_status: response.status,
              p1_environment: config.dig(:p1, :environment)
            }
          )
        end

        def build_http_transport
          p1_config = config.fetch(:p1)
          environment = Constants.environment!(p1_config.fetch(:environment))

          Transports::Http.new(
            base_url: environment.fetch(:base_url),
            tls_bundle:,
            timeout_seconds: p1_config.fetch(:request_timeout_seconds, 180)
          )
        end

        def load_bundle(certificate_config)
          password = ENV.fetch(certificate_config.fetch(:password_env)) do
            raise P1Tool::ConfigurationError,
                  "Missing environment variable: #{certificate_config.fetch(:password_env)}"
          end

          Pkcs12Bundle.load(
            path: File.join(config.fetch(:certificates).fetch(:base_path), certificate_config.fetch(:filename)),
            password:
          )
        end

        def token_headers
          { 'Authorization' => "Bearer #{token}" }
        end

        def token_request_headers
          {
            'Content-Type' => 'application/x-www-form-urlencoded',
            'Accept' => 'application/json'
          }
        end

        def xml_headers
          token_headers.merge('Content-Type' => 'application/xml;charset=UTF-8')
        end

        def handle_response!(response, expected_statuses:, context:)
          return if expected_statuses.include?(response.status)

          body = parse_body(response.body)
          message = "P1 request failed during #{context}: HTTP #{response.status} #{body.inspect}"

          if response.status >= 500
            raise P1Tool::TransientError, message
          end

          raise P1Tool::BusinessError, message
        end

        def parse_body(body)
          return body if body.is_a?(Hash) || body.is_a?(Array)
          return nil if body.nil? || body == ''

          JSON.parse(body)
        rescue JSON::ParserError
          body
        end

        def build_resource_response(response)
          body = parse_body(response.body)

          {
            status: response.status,
            body:,
            headers: response.headers,
            reference_id: body.is_a?(Hash) ? body['id'] : nil,
            version_id: body.is_a?(Hash) ? body.dig('meta', 'versionId') : nil
          }.compact
        end
      end
    end
  end
end
