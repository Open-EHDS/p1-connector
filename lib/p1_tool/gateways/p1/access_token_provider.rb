# frozen_string_literal: true

module P1Tool
  module Gateways
    module P1
      class AccessTokenProvider
        include ResponseHandling

        attr_reader :token

        def initialize(config:, transport:, token_builder:, wss_bundle:)
          @config = config
          @transport = transport
          @token_builder = token_builder
          @wss_bundle = wss_bundle
          @token = nil
        end

        def access_token
          ensure_access_token!
        end

        private

        attr_reader :config, :transport, :token_builder, :wss_bundle

        def ensure_access_token!
          return token if token

          response = request_token
          handle_response!(response, expected_statuses: [200], context: 'access token')
          @token = extract_access_token(response)
          record_token_acquired(response)
          @token
        end

        def token_request_headers
          {
            'Content-Type' => 'application/x-www-form-urlencoded',
            'Accept' => 'application/json'
          }
        end

        def token_request_form
          {
            client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
            grant_type: 'client_credentials',
            client_assertion: token_builder.encode(wss_bundle),
            scope: Constants::FHIR_SCOPE
          }
        end

        def request_token
          transport.request(
            method: :post,
            path: 'token',
            headers: token_request_headers,
            form: token_request_form
          )
        end

        def extract_access_token(response)
          body = parse_body(response.body)
          body.fetch('accessToken') do
            raise P1Tool::BusinessError, "P1 token response does not include accessToken: #{body.inspect}"
          end
        end

        def record_token_acquired(response)
          P1Tool::Adapters::ExecutionEvents.record(
            event_type: 'p1_access_token_acquired',
            metadata: {
              http_status: response.status,
              p1_environment: config.fetch(:p1).fetch(:environment)
            }
          )
        end
      end
    end
  end
end
