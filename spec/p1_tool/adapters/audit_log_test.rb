# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Adapters::AuditLog do
  let(:audit_log_class) { P1Tool::Adapters::AuditLog }
  let(:context) do
    P1Tool::Runtime::ExecutionContext.new(
      transport_id: 'transport-1',
      task_id: 'task-1',
      operation_kind: 'hello_world',
      attempt: 1,
      correlation_id: 'corr-1',
      config_version: 'cfg-v1',
      runtime_mode: 'run_once',
      source_path: '/data/processing/task-1.json'
    )
  end
  let(:time_value) { raise 'time_value must be defined in the example scope' }

  describe '#record_start' do
    let(:time_value) { '2026-04-30T10:00:00Z' }

    it 'appends execution_started entry' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'audit', 'audit.jsonl')
        audit_log = audit_log_class.new(log_path, clock: -> { Time.iso8601(time_value) })

        entry = audit_log.record_start(context, metadata: { source: 'run-once' })

        assert_equal 'execution_started', entry[:event_type]
        assert_equal 'started', entry[:result]
        assert_equal 'cfg-v1', entry[:config_version]

        lines = File.readlines(log_path, chomp: true)

        assert_equal 1, lines.size

        persisted_entry = JSON.parse(lines.first)

        assert_equal '2026-04-30T10:00:00Z', persisted_entry.fetch('timestamp')
        assert_equal 'execution_started', persisted_entry.fetch('event_type')
        assert_equal 'task-1', persisted_entry.fetch('task_id')
        assert_equal({ 'source' => 'run-once' }, persisted_entry.fetch('metadata'))
      end
    end
  end

  describe '#record_finish' do
    let(:time_value) { '2026-04-30T10:00:01Z' }

    it 'appends execution_finished entry' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'audit.jsonl')
        audit_log = audit_log_class.new(log_path, clock: -> { Time.iso8601(time_value) })

        audit_log.record_finish(
          context,
          result: 'success',
          metadata: { duration_ms: 42 }
        )

        persisted_entry = JSON.parse(File.read(log_path))

        assert_equal 'execution_finished', persisted_entry.fetch('event_type')
        assert_equal 'success', persisted_entry.fetch('result')
        assert_equal 'cfg-v1', persisted_entry.fetch('config_version')
        assert_equal({ 'duration_ms' => 42 }, persisted_entry.fetch('metadata'))
      end
    end
  end

  describe '#record_error' do
    let(:time_value) { '2026-04-30T10:00:02Z' }

    it 'appends execution_error entry' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'audit.jsonl')
        audit_log = audit_log_class.new(log_path, clock: -> { Time.iso8601(time_value) })

        audit_log.record_error(
          context,
          error_code: 'invalid_input',
          error_category: 'technical',
          metadata: { detail: 'missing task_id' }
        )

        persisted_entry = JSON.parse(File.read(log_path))

        assert_equal 'execution_error', persisted_entry.fetch('event_type')
        assert_equal 'error', persisted_entry.fetch('result')
        assert_equal 'invalid_input', persisted_entry.fetch('error_code')
        assert_equal 'technical', persisted_entry.fetch('error_category')
      end
    end
  end

  describe '#record_event' do
    let(:time_value) { '2026-04-30T10:00:03Z' }

    it 'appends custom operational event entry' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'audit.jsonl')
        audit_log = audit_log_class.new(log_path, clock: -> { Time.iso8601(time_value) })

        audit_log.record_event(
          context,
          event_type: 'p1_access_token_acquired',
          result: 'success',
          metadata: { http_status: 200 }
        )

        persisted_entry = JSON.parse(File.read(log_path))

        assert_equal 'p1_access_token_acquired', persisted_entry.fetch('event_type')
        assert_equal 'success', persisted_entry.fetch('result')
        assert_equal({ 'http_status' => 200 }, persisted_entry.fetch('metadata'))
      end
    end
  end

  describe 'append-only behavior' do
    let(:time_value) { '2026-04-30T10:00:00Z' }

    it 'appends without overwriting previous entries' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'audit.jsonl')
        audit_log = audit_log_class.new(log_path, clock: -> { Time.iso8601(time_value) })

        audit_log.record_start(context)
        audit_log.record_finish(
          context,
          result: 'success'
        )

        lines = File.readlines(log_path, chomp: true)

        assert_equal 2, lines.size
        assert_equal 'execution_started', JSON.parse(lines[0]).fetch('event_type')
        assert_equal 'execution_finished', JSON.parse(lines[1]).fetch('event_type')
      end
    end
  end
end
