# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Runtime::CurrentExecution do
  let(:context) do
    P1Tool::Runtime::ExecutionContext.new(
      transport_id: 'transport-1',
      task_id: 'task-1',
      operation_kind: 'register_encounter',
      attempt: 1,
      correlation_id: 'corr-1',
      config_version: 'cfg-v1',
      runtime_mode: 'run_once',
      source_path: '/tmp/input.json'
    )
  end

  it 'stores execution-scoped context and writes events through the current audit log' do
    Dir.mktmpdir do |dir|
      log_path = File.join(dir, 'audit.jsonl')
      audit_log = P1Tool::Adapters::AuditLog.new(log_path, clock: -> { Time.utc(2026, 5, 6, 10, 0, 0) })

      P1Tool::Runtime::CurrentExecution.with(context:, audit_log:) do
        updated_context = context.with(task_id: 'task-2')

        P1Tool::Runtime::CurrentExecution.update_context(updated_context)
        P1Tool::Runtime::CurrentExecution.record_event(
          event_type: 'p1_access_token_acquired',
          metadata: { http_status: 200 }
        )

        assert_equal updated_context, P1Tool::Runtime::CurrentExecution.context
      end

      entry = JSON.parse(File.read(log_path))

      assert_equal 'task-2', entry.fetch('task_id')
      assert_equal 'p1_access_token_acquired', entry.fetch('event_type')
      assert_nil P1Tool::Runtime::CurrentExecution.context
      assert_nil P1Tool::Runtime::CurrentExecution.audit_log
    end
  end
end
