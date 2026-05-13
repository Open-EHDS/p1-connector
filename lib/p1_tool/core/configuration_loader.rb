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
        return validation.to_h if validation.success?

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

        normalize_p1_config(config)
        normalize_legacy_certificate_config(config)
        config
      end

      def normalize_p1_config(config)
        config['p1'] ||= { 'environment' => 'integration' }
      end

      def normalize_legacy_certificate_config(config)
        certificates = hash_value(config, 'certificates')
        return unless certificates.is_a?(Hash)
        return if hash_value(certificates, 'wss')

        legacy = certificates.delete('signing') || certificates.delete(:signing)
        certificates['wss'] = legacy if legacy
      end

      def hash_value(hash, key)
        hash[key] || hash[key.to_sym]
      end
    end
  end
end
