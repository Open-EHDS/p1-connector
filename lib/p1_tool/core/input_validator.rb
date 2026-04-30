# frozen_string_literal: true

module P1Tool
  module Core
    class InputValidator
      def self.validate(input, operation_kinds:)
        new(input, operation_kinds: operation_kinds).validate
      end

      def initialize(input, operation_kinds:)
        @input = input
        @operation_kinds = operation_kinds
      end

      def validate
        validation = InputSchema.call(@input)
        details = validation.errors.to_h.dup

        if validation.success?
          normalized_input = deep_symbolize(validation.to_h)
          add_operation_kind_error(details, normalized_input[:operation_kind])
          return normalized_input if details.empty?
        end

        raise P1Tool::InputValidationError.new("Input validation failed", details: details)
      end

      private

      def add_operation_kind_error(details, operation_kind)
        return if @operation_kinds.include?(operation_kind)

        details[:operation_kind] = [
          "must be one of: #{@operation_kinds.join(', ')}"
        ]
      end

      def deep_symbolize(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested_value), result|
            result[key.to_sym] = deep_symbolize(nested_value)
          end
        when Array
          value.map { |item| deep_symbolize(item) }
        else
          value
        end
      end
    end
  end
end
