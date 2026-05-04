# frozen_string_literal: true

require "digest"
require "json"

module P1Tool
  module Runtime
    class ConfigVersion
      def self.for(config)
        new(config).for
      end

      def initialize(config)
        @config = config
      end

      def for
        Digest::SHA256.hexdigest(JSON.generate(canonicalize(@config)))
      end

      private

      def canonicalize(value)
        case value
        when Hash
          value.keys.map(&:to_s).sort.each_with_object({}) do |key, result|
            original_key = value.key?(key) ? key : key.to_sym
            result[key] = canonicalize(value.fetch(original_key))
          end
        when Array
          value.map { |item| canonicalize(item) }
        else
          value
        end
      end
    end
  end
end
