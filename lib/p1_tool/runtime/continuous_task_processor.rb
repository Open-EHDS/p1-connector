# frozen_string_literal: true

module P1Tool
  module Runtime
    class ContinuousTaskProcessor < BaseTaskProcessor
      # rubocop:disable Lint/MissingSuper
      def initialize(config, processing_path:, attempt: 1, correlation_id: nil, runtime: {})
        @config = config
        @processing_path = File.expand_path(processing_path)
        @source_path = @processing_path
        @runtime_mode = 'watch'
        @workspace = runtime_dependency(runtime, :workspace) { P1Tool::Runtime::RuntimeEnvironment.workspace }
        @file_system = runtime_dependency(runtime, :file_system) { @workspace.file_system }
        @clock = runtime_dependency(runtime, :clock) { P1Tool::Runtime::RuntimeEnvironment.clock }
        @transport_id_generator = runtime_dependency(runtime, :transport_id_generator) do
          P1Tool::Runtime::RuntimeEnvironment.transport_id_generator
        end
        @attempt = attempt
        @correlation_id = correlation_id
        @audit_log = runtime_dependency(runtime, :audit_log) { P1Tool::Runtime::RuntimeEnvironment.audit_log }
      end
      # rubocop:enable Lint/MissingSuper

      private

      attr_reader :config, :source_path, :runtime_mode, :audit_log, :clock, :transport_id_generator, :attempt,
                  :correlation_id, :file_system

      def start_metadata
        { source_path: @processing_path }
      end

      def finalize_terminal_result(context, result, result_kind:)
        output_path = @workspace.write_result(@processing_path, result)
        audit_log.record_finish(context, result: result_kind, metadata: { output_path: output_path })
        if result_kind == 'invalid'
          @workspace.move_to_invalid(@processing_path)
        else
          @workspace.move_to_done(@processing_path)
        end
        result
      end

      def failure_category_for(error)
        P1Tool::Runtime::RetryPolicy.category_for(error)
      end

      def retryable_failure?(category)
        P1Tool::Runtime::RetryPolicy.retryable?(category) &&
          !P1Tool::Runtime::RetryPolicy.exhausted?(attempt)
      end

      def handle_retryable_failure(context, error, category)
        record_error(
          context,
          error_code: 'runtime_error',
          error_category: category,
          metadata: retry_metadata(error),
          result: 'failure'
        )
        audit_log.record_finish(
          context,
          result: 'failure',
          metadata: { retry_scheduled: true, next_attempt: attempt + 1 }
        )
        raise error
      end

      def retry_metadata(error)
        {
          exception_class: error.class.name,
          message: error.message,
          retry_scheduled: true,
          next_attempt: attempt + 1
        }.merge(structured_error_attributes(error))
      end

      def runtime_dependency(runtime, key, &fallback) = runtime.key?(key) ? runtime[key] : fallback.call
    end
  end
end
