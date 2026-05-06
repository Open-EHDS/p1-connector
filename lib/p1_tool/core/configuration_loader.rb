# frozen_string_literal: true

require 'erb'
require 'yaml'

module P1Tool
  module Core
    class ConfigurationLoader
      def self.load(path)
        new(path).load
      end

      def initialize(path)
        @path = File.expand_path(path)
      end

      def load
        raise P1Tool::ConfigurationError, "Config file not found: #{@path}" unless File.file?(@path)

        parsed_config = normalize_config(parse_yaml)

        raise P1Tool::ConfigurationError, 'Config root must be a YAML mapping' unless parsed_config.is_a?(Hash)

        validation = ConfigurationSchema.call(parsed_config)
        if validation.success?
          config = validation.to_h
          validate_semantics!(config)
          return config
        end

        raise P1Tool::ConfigurationError.new(
          "Config validation failed for #{@path}",
          details: validation.errors.to_h
        )
      end

      private

      def parse_yaml
        rendered_config = render_erb
        YAML.safe_load(rendered_config, aliases: false)
      rescue Psych::SyntaxError => e
        raise P1Tool::ConfigurationError, "Invalid YAML in #{@path}: #{e.message}"
      end

      def render_erb
        ERB.new(File.read(@path)).result(binding)
      rescue StandardError => e
        raise P1Tool::ConfigurationError, "Invalid ERB in #{@path}: #{e.message}"
      end

      def normalize_config(config)
        return config unless config.is_a?(Hash)

        config['p1'] ||= { 'environment' => 'integration' }

        certificates = config['certificates'] || config[:certificates]
        return config unless certificates.is_a?(Hash)

        if certificates['wss'].nil? && certificates[:wss].nil?
          legacy = certificates.delete('signing') || certificates.delete(:signing)
          certificates['wss'] = legacy if legacy
        end

        config
      end

      def validate_semantics!(config)
        validate_certificates!(config)
      end

      def validate_certificates!(config)
        certificates = config.fetch(:certificates)
        validate_certificate!(certificates, :wss)
        validate_certificate!(certificates, :tls)
      end

      def validate_certificate!(certificates, kind)
        certificate_config = certificates.fetch(kind)
        password_env = certificate_config.fetch(:password_env)
        password = ENV.fetch(password_env) do
          raise P1Tool::ConfigurationError.new(
            "Config validation failed for #{@path}",
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
          "Config validation failed for #{@path}",
          details: { certificates: { kind => { filename: [e.message] } } }
        )
      end
    end
  end
end
