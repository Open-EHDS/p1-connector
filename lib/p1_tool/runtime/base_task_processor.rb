# frozen_string_literal: true

require 'json'

module P1Tool
  module Runtime
    class BaseTaskProcessor
      def call
        started_at = timestamp
        context = build_context

        P1Tool::Runtime::CurrentExecution.with(context:, audit_log:) do
          audit_log.record_start(context, metadata: start_metadata)
          process_input(context, started_at)
        rescue P1Tool::InputValidationError, JSON::ParserError => e
          handle_invalid_input(current_context(context), started_at, e)
        rescue StandardError => e
          handle_failure(current_context(context), started_at, e)
        end
      end

      private

      def build_context
        transport_id = transport_id_generator.call

        P1Tool::Runtime::ExecutionContext.new(
          transport_id: transport_id,
          task_id: nil,
          operation_kind: nil,
          attempt: attempt,
          correlation_id: correlation_id || transport_id,
          config_version: P1Tool::Runtime::ConfigVersion.for(config),
          runtime_mode: runtime_mode,
          source_path: source_path
        )
      end

      def parse_input_file
        JSON.parse(File.read(source_path))
      end

      def process_input(context, started_at)
        validated_context, validated_input = validate_input(context)
        operation_result = P1Tool::Application::Dispatcher.call_with_config(validated_input, config:)
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
        update_current_context(
          context.with(
            task_id: input[:task_id] || input['task_id'],
            operation_kind: input[:operation_kind] || input['operation_kind']
          )
        )
      end

      def handle_invalid_input(context, started_at, error)
        result = build_result(
          context,
          result_kind: 'invalid',
          timestamps: build_timestamps(started_at),
          error: build_error('invalid_input', error.message, 'input', source_error: error),
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
        category = failure_category_for(error)
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

      def build_failure_result(context, started_at, error, category)
        build_result(
          context,
          result_kind: 'failure',
          timestamps: build_timestamps(started_at),
          error: build_error('runtime_error', error.message, category, source_error: error),
          details: { exception_class: error.class.name }
        )
      end

      def build_error(code, message, category, source_error: nil)
        {
          code: code,
          message: message,
          category: category
        }.merge(structured_error_attributes(source_error))
      end

      def invalid_details(error)
        return nil unless error.respond_to?(:details)
        return nil if error.details.nil? || error.details.empty?

        { validation_errors: error.details }
      end

      def record_error(context, error_code:, error_category:, metadata:, result:)
        audit_log.record_error(
          context,
          error_code: error_code,
          error_category: error_category,
          metadata: metadata,
          result: result
        )
      end

      def structured_error_attributes(error)
        return {} unless error.respond_to?(:details)

        details = error.details
        return {} unless details.is_a?(Hash)

        {}.tap do |attributes|
          attributes[:http_status] = details[:http_status] if details.key?(:http_status)
          attributes[:body] = details[:body] if details.key?(:body)
        end
      end

      def update_current_context(context)
        P1Tool::Runtime::CurrentExecution.update_context(context)
      end

      def current_context(fallback)
        P1Tool::Runtime::CurrentExecution.context || fallback
      end

      def terminal_failure_metadata(error)
        {
          exception_class: error.class.name,
          message: error.message
        }.merge(structured_error_attributes(error))
      end

      def failure_category_for(_error)
        'technical'
      end

      def retryable_failure?(_category)
        false
      end

      def timestamp
        clock.call.iso8601
      end

      def config
        raise NotImplementedError, "#{self.class} must implement ##{__method__}"
      end

      def source_path
        raise NotImplementedError, "#{self.class} must implement ##{__method__}"
      end

      def runtime_mode
        raise NotImplementedError, "#{self.class} must implement ##{__method__}"
      end

      def audit_log
        raise NotImplementedError, "#{self.class} must implement ##{__method__}"
      end

      def clock
        raise NotImplementedError, "#{self.class} must implement ##{__method__}"
      end

      def transport_id_generator
        raise NotImplementedError, "#{self.class} must implement ##{__method__}"
      end

      def attempt = 1

      def correlation_id = nil

      def start_metadata
        raise NotImplementedError, "#{self.class} must implement ##{__method__}"
      end

      def finalize_terminal_result(_context, _result, result_kind:)
        raise NotImplementedError, "#{self.class} must implement ##{__method__}"
      end

      def handle_retryable_failure(_context, error, _category)
        raise error
      end
    end
  end
end
