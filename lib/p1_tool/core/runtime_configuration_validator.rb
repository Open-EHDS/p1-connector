# frozen_string_literal: true

module P1Tool
  module Core
    class RuntimeConfigurationValidator
      def self.validate!(config, path: nil)
        new(config, path:).validate!
      end

      def initialize(config, path: nil)
        @config = config
        @path = path ? File.expand_path(path) : nil
      end

      def validate!
        validate_certificates!
        config
      end

      private

      attr_reader :config, :path

      def validate_certificates!
        certificates = config.fetch(:certificates)
        validate_certificate!(certificates, :wss)
        validate_certificate!(certificates, :tls)
      end

      def validate_certificate!(certificates, kind)
        certificate_config = certificates.fetch(kind)
        password_env = certificate_config.fetch(:password_env)
        password = ENV.fetch(password_env) do
          raise P1Tool::ConfigurationError.new(
            validation_error_message,
            details: { certificates: { kind => { password_env: ["environment variable #{password_env} is missing"] } } }
          )
        end

        P1Tool::Gateways::P1::Pkcs12Bundle.load(
          path: File.join(certificates.fetch(:base_path), certificate_config.fetch(:filename)),
          password:
        )
      rescue P1Tool::ConfigurationError => e
        raise e
      rescue StandardError => e
        raise P1Tool::ConfigurationError.new(
          validation_error_message,
          details: { certificates: { kind => { filename: [e.message] } } }
        )
      end

      def validation_error_message
        return 'Runtime configuration validation failed' if path.nil?

        "Runtime configuration validation failed for #{path}"
      end
    end
  end
end
