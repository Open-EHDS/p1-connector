# frozen_string_literal: true

require 'faraday'
require 'json'

module P1Tool
  module Gateways
    module SignatureService
      class Client
        def initialize(base_url:, timeout_seconds: 180, connection_factory: nil)
          @base_url = base_url
          @timeout_seconds = timeout_seconds
          @connection_factory = connection_factory
        end

        def generate_signature(documents:)
          response = connection.post('api/v1/signatures/xades-detached') do |request|
            request.headers['Content-Type'] = 'application/json'
            request.headers['Accept'] = 'application/json'
            request.body = JSON.generate(documents:)
          end

          body = parse_body(response.body)
          handle_response!(response, body)

          unless body.is_a?(Hash) && (body.key?('document') || body.key?('documentBase64'))
            raise P1Tool::BusinessError, "Signature service response does not include document or documentBase64: #{body.inspect}"
          end

          body
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
          raise P1Tool::TransientError, "Signature service request failed: #{e.message}"
        end

        private

        attr_reader :base_url, :timeout_seconds, :connection_factory

        def connection
          @connection ||= begin
            if connection_factory
              connection_factory.call
            else
              Faraday.new(url: base_url) do |faraday|
                faraday.options.timeout = timeout_seconds
                faraday.adapter Faraday.default_adapter
              end
            end
          end
        end

        def parse_body(body)
          return nil if body.nil? || body == ''

          JSON.parse(body)
        rescue JSON::ParserError
          body
        end

        def handle_response!(response, body)
          return if response.status == 200

          message = "Signature service request failed: HTTP #{response.status}"
          details = { http_status: response.status, body: }

          raise P1Tool::TransientError.new(message, details: details) if response.status >= 500

          raise P1Tool::BusinessError.new(message, details: details)
        end
      end
    end
  end
end
