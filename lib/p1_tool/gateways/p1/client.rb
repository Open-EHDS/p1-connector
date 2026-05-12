# frozen_string_literal: true

module P1Tool
  module Gateways
    module P1
      class Client
        include ResponseHandling

        def initialize(transport:, access_token_provider:)
          @transport = transport
          @access_token_provider = access_token_provider
        end

        def token = access_token_provider.token

        def access_token
          access_token_provider.access_token
        end

        def create_resource(resource_type:, xml:)
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
          response = transport.request(
            method: :get,
            path: resource_path(resource_type:, reference_id:),
            headers: json_headers
          )
          handle_response!(response, expected_statuses: [200], context: "get #{resource_type} #{reference_id}")
          { status: response.status, body: parse_body(response.body), headers: response.headers }
        end

        def get_resource_xml(resource_type:, reference_id:, version_id: nil)
          response = transport.request(
            method: :get,
            path: resource_path(resource_type:, reference_id:, version_id:),
            headers: xml_accept_headers
          )
          context = build_get_xml_context(resource_type, reference_id, version_id)
          handle_response!(response, expected_statuses: [200], context:)

          {
            status: response.status,
            body: response.body.to_s,
            headers: response.headers
          }
        end

        def destroy_resource(resource_type:, reference_id:)
          response = transport.request(
            method: :delete,
            path: resource_path(resource_type:, reference_id:),
            headers: token_headers
          )
          handle_response!(response, expected_statuses: [200], context: "delete #{resource_type} #{reference_id}")

          {
            status: response.status,
            body: parse_body(response.body),
            headers: response.headers
          }
        end

        def find_patient(payload:)
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

        attr_reader :transport, :access_token_provider

        def token_headers
          { 'Authorization' => "Bearer #{access_token_provider.access_token}" }
        end

        def xml_headers
          token_headers.merge('Content-Type' => 'application/xml;charset=UTF-8')
        end

        def json_headers
          token_headers.merge('Accept' => 'application/fhir+json')
        end

        def xml_accept_headers
          token_headers.merge('Accept' => 'application/fhir+xml')
        end

        def resource_path(resource_type:, reference_id:, version_id: nil)
          path = "fhir/#{resource_type}/#{reference_id}"
          return path if version_id.nil? || version_id == ''

          "#{path}/_history/#{version_id}"
        end

        def build_get_xml_context(resource_type, reference_id, version_id)
          if version_id
            "get #{resource_type} #{reference_id} version #{version_id} as xml"
          else
            "get #{resource_type} #{reference_id} as xml"
          end
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
