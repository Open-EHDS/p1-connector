# frozen_string_literal: true

module P1Tool
  module Runtime
    class TaskProcessor < BaseTaskProcessor
      # rubocop:disable Lint/MissingSuper
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
        @source_path = File.expand_path(input_path)
        @runtime_mode = 'run_once'
        @output_path = File.expand_path(output_path)
        @file_system = file_system
        @clock = clock
        @transport_id_generator = transport_id_generator
        @audit_log = audit_log || P1Tool::Adapters::AuditLog.new(config.dig(:paths, :audit_log), file_system:, clock:)
      end
      # rubocop:enable Lint/MissingSuper

      private

      attr_reader :config, :source_path, :runtime_mode, :audit_log, :file_system, :clock, :transport_id_generator

      def start_metadata
        { output_path: @output_path }
      end

      def persist_result(result)
        payload = "#{JSON.pretty_generate(result)}\n"
        @file_system.atomic_write(@output_path, payload)
      end

      def finalize_terminal_result(context, result, result_kind:)
        persist_result(result)
        audit_log.record_finish(context, result: result_kind, metadata: { output_path: @output_path })
        result
      end
    end
  end
end
