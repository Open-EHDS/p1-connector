# frozen_string_literal: true

module P1Tool
  module Runtime
    class ExecutionContext
      ATTRIBUTES = %i[
        transport_id
        task_id
        operation_kind
        attempt
        correlation_id
        config_version
        runtime_mode
        source_path
      ].freeze

      attr_reader(*ATTRIBUTES)

      def initialize(
        transport_id:,
        task_id:,
        operation_kind:,
        attempt:,
        correlation_id:,
        config_version: nil,
        runtime_mode: nil,
        source_path: nil
      )
        @transport_id = transport_id
        @task_id = task_id
        @operation_kind = operation_kind
        @attempt = attempt
        @correlation_id = correlation_id
        @config_version = config_version
        @runtime_mode = runtime_mode
        @source_path = source_path
      end

      def to_h
        ATTRIBUTES.each_with_object({}) do |attribute, result|
          value = public_send(attribute)
          result[attribute] = value unless value.nil?
        end
      end
    end
  end
end
