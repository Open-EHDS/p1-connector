# frozen_string_literal: true

module P1Tool
  module Adapters
    module ExecutionEvents
      module_function

      def record(event_type:, metadata: nil, result: 'success')
        P1Tool::Runtime::CurrentExecution.record_event(
          event_type:,
          metadata:,
          result:
        )
      end
    end
  end
end
