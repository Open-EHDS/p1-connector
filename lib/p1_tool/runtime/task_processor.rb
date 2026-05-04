# frozen_string_literal: true

require "json"
require "securerandom"
require "time"

module P1Tool
  module Runtime
    class TaskProcessor
      def initialize(
        config,
        input_path:,
        output_path:,
        audit_log: nil,
        file_system: P1Tool::Adapters::FileSystem.new,
        clock: -> { Time.now.utc },
        transport_id_generator: -> { SecureRandom.uuid }
      )
        @config = config
        @input_path = File.expand_path(input_path)
        @output_path = File.expand_path(output_path)
        @file_system = file_system
        @clock = clock
        @transport_id_generator = transport_id_generator
        @audit_log = audit_log || P1Tool::Adapters::AuditLog.new(config.dig(:paths, :audit_log), file_system: file_system, clock: clock)
      end

      def call
        started_at = timestamp
        context = build_context

        @audit_log.record_start(context, metadata: { output_path: @output_path })

        parsed_input = parse_input_file
        context = context.with(
          task_id: parsed_input["task_id"],
          operation_kind: parsed_input["operation_kind"]
        )

        validated_input = P1Tool::Core::InputValidator.validate(
          parsed_input,
          operation_kinds: P1Tool::Application::Dispatcher.supported_operation_kinds
        )

        context = context.with(
          task_id: validated_input[:task_id],
          operation_kind: validated_input[:operation_kind]
        )

        operation_result = P1Tool::Application::Dispatcher.call(validated_input)
        result = build_result(
          context,
          result_kind: "success",
          started_at: started_at,
          finished_at: timestamp,
          details: operation_result
        )

        persist_result(result)
        @audit_log.record_finish(context, result: "success", metadata: { output_path: @output_path })

        result
      rescue P1Tool::InputValidationError, JSON::ParserError => error
        handle_invalid_input(context, started_at, error)
      rescue StandardError => error
        handle_failure(context, started_at, error)
      end

      private

      def build_context
        transport_id = @transport_id_generator.call

        P1Tool::Runtime::ExecutionContext.new(
          transport_id: transport_id,
          task_id: nil,
          operation_kind: nil,
          attempt: 1,
          correlation_id: transport_id,
          config_version: P1Tool::Runtime::ConfigVersion.for(@config),
          runtime_mode: "run_once",
          source_path: @input_path
        )
      end

      def parse_input_file
        JSON.parse(File.read(@input_path))
      end

      def handle_invalid_input(context, started_at, error)
        result = build_result(
          context,
          result_kind: "invalid",
          started_at: started_at,
          finished_at: timestamp,
          error: build_error("invalid_input", error.message, "input"),
          details: invalid_details(error)
        )

        persist_result(result)
        @audit_log.record_error(
          context,
          error_code: "invalid_input",
          error_category: "input",
          metadata: invalid_details(error),
          result: "invalid"
        )
        @audit_log.record_finish(context, result: "invalid", metadata: { output_path: @output_path })

        result
      end

      def handle_failure(context, started_at, error)
        result = build_result(
          context,
          result_kind: "failure",
          started_at: started_at,
          finished_at: timestamp,
          error: build_error("runtime_error", error.message, "technical"),
          details: { exception_class: error.class.name }
        )

        persist_result(result)
        @audit_log.record_error(
          context,
          error_code: "runtime_error",
          error_category: "technical",
          metadata: { exception_class: error.class.name, message: error.message },
          result: "failure"
        )
        @audit_log.record_finish(context, result: "failure", metadata: { output_path: @output_path })

        result
      end

      def build_result(context, result_kind:, started_at:, finished_at:, error: nil, details: nil)
        result = {
          transport_id: context.transport_id,
          task_id: context.task_id,
          operation_kind: context.operation_kind,
          result_kind: result_kind,
          config_version: context.config_version,
          attempt: context.attempt,
          started_at: started_at,
          finished_at: finished_at
        }

        result[:error] = error unless error.nil?
        result[:details] = details unless details.nil?
        result
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

      def persist_result(result)
        payload = JSON.pretty_generate(result) + "\n"
        @file_system.atomic_write(@output_path, payload)
      end

      def timestamp
        @clock.call.iso8601
      end
    end
  end
end
