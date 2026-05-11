# frozen_string_literal: true

module P1Tool
  module Application
    class Dispatcher
      OPERATIONS = {
        'register_encounter' => Operations::RegisterEncounter,
        'register_procedure' => Operations::RegisterProcedure,
        'register_condition' => Operations::RegisterCondition
      }.freeze

      def self.call(input)
        new(input).call
      end

      def self.call_with_config(input, config:)
        new(input, config: config).call
      end

      def self.supported_operation_kinds
        OPERATIONS.keys
      end

      def initialize(input, config: nil)
        @input = input
        @config = config
      end

      def call
        operation_class.call(@input, config: @config)
      end

      private

      def operation_class
        OPERATIONS.fetch(@input.fetch(:operation_kind))
      rescue KeyError
        raise P1Tool::InputValidationError.new(
          'Unsupported operation_kind',
          details: { operation_kind: ["must be one of: #{self.class.supported_operation_kinds.join(', ')}"] }
        )
      end
    end
  end
end
