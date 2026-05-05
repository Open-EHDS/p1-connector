# frozen_string_literal: true

require 'yaml'

module P1Tool
  module Runtime
    class SidekiqConfigLoader
      def self.load(path)
        new(path).load
      end

      def initialize(path)
        @path = File.expand_path(path)
      end

      def load
        raise P1Tool::ConfigurationError, "Config file not found: #{@path}" unless File.file?(@path)

        parsed = YAML.safe_load_file(@path, aliases: false)
        parsed = {} if parsed.nil?

        raise P1Tool::ConfigurationError, "Config root must be a YAML mapping: #{@path}" unless parsed.is_a?(Hash)

        stringify_keys(parsed)
      rescue Psych::SyntaxError => e
        raise P1Tool::ConfigurationError, "Invalid YAML in #{@path}: #{e.message}"
      end

      private

      def stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested_value), result|
            result[key.to_s] = stringify_keys(nested_value)
          end
        when Array
          value.map { |item| stringify_keys(item) }
        else
          value
        end
      end
    end
  end
end
