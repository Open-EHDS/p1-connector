# frozen_string_literal: true

require "yaml"

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

        parsed_config = parse_yaml

        unless parsed_config.is_a?(Hash)
          raise P1Tool::ConfigurationError, "Config root must be a YAML mapping"
        end

        validation = ConfigurationSchema.call(parsed_config)
        return validation.to_h if validation.success?

        raise P1Tool::ConfigurationError.new(
          "Config validation failed for #{@path}",
          details: validation.errors.to_h
        )
      end

      private

      def parse_yaml
        YAML.safe_load(File.read(@path), aliases: false)
      rescue Psych::SyntaxError => e
        raise P1Tool::ConfigurationError, "Invalid YAML in #{@path}: #{e.message}"
      end
    end
  end
end
