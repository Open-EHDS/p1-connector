# frozen_string_literal: true

require 'json'

module P1Tool
  module Gateways
    module P1
      module ResponseHandling
        private

        def handle_response!(response, expected_statuses:, context:)
          return if expected_statuses.include?(response.status)

          body = parse_body(response.body)
          message = "P1 request failed during #{context}: HTTP #{response.status}"
          details = { http_status: response.status, body: body }

          raise P1Tool::TransientError.new(message, details: details) if response.status >= 500

          raise P1Tool::BusinessError.new(message, details: details)
        end

        def parse_body(body)
          return body if body.is_a?(Hash) || body.is_a?(Array)
          return nil if body.nil? || body == ''

          JSON.parse(body)
        rescue JSON::ParserError
          body
        end
      end
    end
  end
end
