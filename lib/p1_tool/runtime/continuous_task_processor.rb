# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'time'

module P1Tool
  module Runtime
    class ContinuousTaskProcessor
      def initialize(
        config,
        processing_path:,
        attempt: 1,
        correlation_id: nil,
        runtime: {}
      )
        @config = config
        @processing_path = File.expand_path(processing_path)
        @workspace = runtime_dependency(runtime, :workspace) { P1Tool::Runtime::RuntimeEnvironment.workspace }
        @file_system = runtime_dependency(runtime, :file_system) { P1Tool::Adapters::FileSystem.new }
        @clock = runtime_dependency(runtime, :clock) { P1Tool::Runtime::RuntimeEnvironment.clock }
        @transport_id_generator = runtime_dependency(runtime, :transport_id_generator) do
          P1Tool::Runtime::RuntimeEnvironment.transport_id_generator
        end
        @attempt = attempt
        @correlation_id = correlation_id
        @audit_log = runtime_dependency(runtime, :audit_log) { P1Tool::Runtime::RuntimeEnvironment.audit_log }
      end

      def call
        started_at = timestamp
        context = build_context
        @audit_log.record_start(context, metadata: { source_path: @processing_path })
        process_input(context, started_at)
      rescue P1Tool::InputValidationError, JSON::ParserError => e
        handle_invalid_input(context, started_at, e)
      rescue StandardError => e
        handle_failure(context, started_at, e)
      end

      private

      def build_context
        transport_id = @transport_id_generator.call
        P1Tool::Runtime::ExecutionContext.new(
          transport_id: transport_id,
          task_id: nil,
          operation_kind: nil,
          attempt: @attempt,
          correlation_id: @correlation_id || transport_id,
          config_version: P1Tool::Runtime::ConfigVersion.for(@config),
          runtime_mode: 'watch',
          source_path: @processing_path
        )
      end

      def parse_input_file = JSON.parse(File.read(@processing_path))

      def process_input(context, started_at)
        validated_context, validated_input = validate_input(context)
        operation_result = P1Tool::Application::Dispatcher.call(validated_input)
        result = build_result(
          validated_context,
          result_kind: 'success',
          timestamps: build_timestamps(started_at),
          details: operation_result
        )
        finalize_terminal_result(validated_context, result, result_kind: 'success')
      end

      def validate_input(context)
        parsed_input = parse_input_file
        parsed_context = context_from_input(context, parsed_input)
        validated_input = P1Tool::Core::InputValidator.validate(
          parsed_input,
          operation_kinds: P1Tool::Application::Dispatcher.supported_operation_kinds
        )
        [context_from_input(parsed_context, validated_input), validated_input]
      end

      def context_from_input(context, input)
        context.with(
          task_id: input[:task_id] || input['task_id'],
          operation_kind: input[:operation_kind] || input['operation_kind']
        )
      end

      def handle_invalid_input(context, started_at, error)
        result = build_result(
          context,
          result_kind: 'invalid',
          timestamps: build_timestamps(started_at),
          error: build_error('invalid_input', error.message, 'input'),
          details: invalid_details(error)
        )
        record_error(
          context,
          error_code: 'invalid_input',
          error_category: 'input',
          metadata: invalid_details(error),
          result: 'invalid'
        )
        finalize_terminal_result(context, result, result_kind: 'invalid')
      end

      def handle_failure(context, started_at, error)
        category = P1Tool::Runtime::RetryPolicy.category_for(error)
        result = build_failure_result(context, started_at, error, category)

        return handle_retryable_failure(context, error, category) if retryable_failure?(category)

        record_error(
          context,
          error_code: 'runtime_error',
          error_category: category,
          metadata: terminal_failure_metadata(error),
          result: 'failure'
        )
        finalize_terminal_result(context, result, result_kind: 'failure')
      end

      def build_result(context, result_kind:, timestamps:, error: nil, details: nil)
        result = {
          transport_id: context.transport_id,
          task_id: context.task_id,
          operation_kind: context.operation_kind,
          result_kind: result_kind,
          config_version: context.config_version,
          attempt: context.attempt,
          started_at: timestamps.fetch(:started_at),
          finished_at: timestamps.fetch(:finished_at)
        }
        result[:error] = error unless error.nil?
        result[:details] = details unless details.nil?
        result
      end

      def build_timestamps(started_at)
        {
          started_at: started_at,
          finished_at: timestamp
        }
      end

      def build_error(code, message, category)
        {
          code: code,
          message: message,
          category: category
        }
      end

      def invalid_details(error)
        return nil unless error.respond_to?(:details)
        return nil if error.details.nil? || error.details.empty?

        { validation_errors: error.details }
      end

      def record_error(context, error_code:, error_category:, metadata:, result:)
        @audit_log.record_error(
          context,
          error_code: error_code,
          error_category: error_category,
          metadata: metadata,
          result: result
        )
      end

      def finalize_terminal_result(context, result, result_kind:)
        output_path = @workspace.write_result(@processing_path, result)
        @audit_log.record_finish(context, result: result_kind, metadata: { output_path: output_path })
        if result_kind == 'invalid'
          @workspace.move_to_invalid(@processing_path)
        else
          @workspace.move_to_done(@processing_path)
        end
        result
      end

      def build_failure_result(context, started_at, error, category)
        build_result(
          context,
          result_kind: 'failure',
          timestamps: build_timestamps(started_at),
          error: build_error('runtime_error', error.message, category),
          details: { exception_class: error.class.name }
        )
      end

      def retryable_failure?(category)
        P1Tool::Runtime::RetryPolicy.retryable?(category) &&
          !P1Tool::Runtime::RetryPolicy.exhausted?(@attempt)
      end

      def handle_retryable_failure(context, error, category)
        record_error(
          context,
          error_code: 'runtime_error',
          error_category: category,
          metadata: retry_metadata(error),
          result: 'failure'
        )
        @audit_log.record_finish(
          context,
          result: 'failure',
          metadata: { retry_scheduled: true, next_attempt: @attempt + 1 }
        )
        raise error
      end

      def retry_metadata(error)
        {
          exception_class: error.class.name,
          message: error.message,
          retry_scheduled: true,
          next_attempt: @attempt + 1
        }
      end

      def terminal_failure_metadata(error)
        {
          exception_class: error.class.name,
          message: error.message
        }
      end

      def timestamp = @clock.call.iso8601

      def runtime_dependency(runtime, key, &fallback) = runtime.key?(key) ? runtime[key] : fallback.call
    end
  end
end
