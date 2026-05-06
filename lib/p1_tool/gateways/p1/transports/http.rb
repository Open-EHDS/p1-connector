# frozen_string_literal: true

require 'faraday'
require 'uri'

module P1Tool
  module Gateways
    module P1
      module Transports
        class Http
          Response = Struct.new(:status, :headers, :body, keyword_init: true)

          def initialize(base_url:, tls_bundle:, timeout_seconds: 180)
            @base_url = base_url
            @tls_bundle = tls_bundle
            @timeout_seconds = timeout_seconds
          end

          def request(method:, path:, headers: {}, params: nil, body: nil, form: nil)
            response = connection(headers:).public_send(method) do |request|
              request.url(path, params || {})
              request.body = URI.encode_www_form(form) if form
              request.body = body if body
            end

            Response.new(status: response.status, headers: response.headers.to_h, body: response.body)
          rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
            raise P1Tool::TransientError, "P1 HTTP request failed: #{e.message}"
          end

          private

          attr_reader :base_url, :tls_bundle, :timeout_seconds

          def connection(headers:)
            Faraday.new(
              url: base_url,
              ssl: {
                client_cert: tls_bundle.certificate,
                client_key: tls_bundle.key
              }
            ) do |faraday|
              faraday.headers = headers
              faraday.options.timeout = timeout_seconds
              faraday.adapter Faraday.default_adapter
            end
          end
        end
      end
    end
  end
end
