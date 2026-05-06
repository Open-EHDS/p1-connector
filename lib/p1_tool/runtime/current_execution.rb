# frozen_string_literal: true

module P1Tool
  module Runtime
    module CurrentExecution
      THREAD_KEY = :p1_tool_current_execution

      class << self
        def with(context:, audit_log:, &block)
          previous = Thread.current[THREAD_KEY]
          Thread.current[THREAD_KEY] = { context:, audit_log: }
          block.call
        ensure
          Thread.current[THREAD_KEY] = previous
        end

        def context
          state&.fetch(:context, nil)
        end

        def audit_log
          state&.fetch(:audit_log, nil)
        end

        def update_context(context)
          return context unless state

          state[:context] = context
          context
        end

        def record_event(event_type:, metadata: nil, result: 'success')
          return unless state

          audit_log.record_event(context, event_type:, metadata:, result:)
        end

        private

        def state
          Thread.current[THREAD_KEY]
        end
      end
    end
  end
end
