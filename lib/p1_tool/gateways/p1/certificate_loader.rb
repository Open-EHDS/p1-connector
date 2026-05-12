# frozen_string_literal: true

module P1Tool
  module Gateways
    module P1
      class CertificateLoader
        def initialize(config:)
          @config = config
        end

        def load(kind)
          certificate_config = certificates.fetch(kind)
          password = ENV.fetch(certificate_config.fetch(:password_env)) do
            raise P1Tool::ConfigurationError,
                  "Missing environment variable: #{certificate_config.fetch(:password_env)}"
          end

          Pkcs12Bundle.load(
            path: File.join(certificates.fetch(:base_path), certificate_config.fetch(:filename)),
            password:
          )
        end

        private

        attr_reader :config

        def certificates
          config.fetch(:certificates)
        end
      end
    end
  end
end
