# frozen_string_literal: true

module P1Tool
  module Gateways
    module P1
      class ClientFactory
        def self.build(config:, doctor:, transport: nil, certificate_loader: nil, clock: -> { Time.now.utc })
          new(config:, doctor:, transport:, certificate_loader:, clock:).build
        end

        def initialize(config:, doctor:, transport: nil, certificate_loader: nil, clock: -> { Time.now.utc })
          @config = config
          @doctor = doctor
          @transport = transport
          @certificate_loader = certificate_loader || CertificateLoader.new(config:)
          @clock = clock
        end

        def build
          tls_bundle = certificate_loader.load(:tls)
          wss_bundle = certificate_loader.load(:wss)
          resolved_transport = transport || build_http_transport(tls_bundle)
          token_builder = TokenBuilder.new(subject: config.fetch(:subject), doctor:, clock:)
          access_token_provider = AccessTokenProvider.new(
            config:,
            transport: resolved_transport,
            token_builder:,
            wss_bundle:
          )

          Client.new(
            transport: resolved_transport,
            access_token_provider:
          )
        end

        private

        attr_reader :config, :doctor, :transport, :certificate_loader, :clock

        def build_http_transport(tls_bundle)
          p1_config = config.fetch(:p1)
          environment = Constants.environment!(p1_config.fetch(:environment))

          Transports::Http.new(
            base_url: environment.fetch(:base_url),
            tls_bundle: tls_bundle,
            timeout_seconds: p1_config.fetch(:request_timeout_seconds, 180)
          )
        end
      end
    end
  end
end
