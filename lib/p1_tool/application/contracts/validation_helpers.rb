# frozen_string_literal: true

module P1Tool
  module Application
    module Contracts
      module ValidationHelpers
        private

        def deep_symbolize(value)
          case value
          when Hash then value.each_with_object({}) { |(key, nested), result| result[key.to_sym] = deep_symbolize(nested) }
          when Array then value.map { |item| deep_symbolize(item) }
          else value
          end
        end

        def append_error(details, group, field, message)
          details[group] ||= {}
          details[group][field] ||= []
          details[group][field] << message
        end

        def blank?(value)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end
    end
  end
end
