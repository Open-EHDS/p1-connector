# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Runtime::ContinuousTaskProcessor do
  let(:processor_class) { P1Tool::Runtime::ContinuousTaskProcessor }
  let(:tmpdir) { Dir.mktmpdir }
  let(:transport_id) { 'transport-1' }
  let(:audit_log_path) { File.join(tmpdir, 'logs', 'audit.jsonl') }
  let(:config) { runtime_config_for(tmpdir, audit_log_path:) }
  let(:workspace) { P1Tool::Runtime::Workspace.new(config) }
  let(:clock) do
    times = [
      Time.iso8601('2026-05-05T10:00:00Z'),
      Time.iso8601('2026-05-05T10:00:01Z')
    ]

    -> { times.shift || Time.iso8601('2026-05-05T10:00:01Z') }
  end
  let(:audit_log) { P1Tool::Adapters::AuditLog.new(audit_log_path, clock:) }

  before do
    workspace.prepare!
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  it 'stores success result and moves file to done' do
    processing_path = File.join(workspace.path_for(:processing), 'task-1.json')
    File.write(processing_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))

    result = with_fake_p1_client_factory do
      processor_class.new(
        config,
        processing_path:,
        runtime: {
          workspace:,
          audit_log:,
          clock:,
          transport_id_generator: -> { transport_id }
        }
      ).call
    end

    assert_equal 'success', result[:result_kind]
    assert_equal 1, result[:attempt]
    assert_path_exists File.join(workspace.path_for(:done), 'task-1.json')
    result_path = File.join(workspace.path_for(:results), 'task-1.json.result.json')

    assert_equal 'success', JSON.parse(File.read(result_path)).fetch('result_kind')

    audit_lines = File.readlines(audit_log_path, chomp: true).map { |line| JSON.parse(line) }

    assert_equal(
      %w[
        execution_started
        p1_patient_lookup_finished
        p1_encounter_submitted
        execution_finished
      ],
      audit_lines.map { |entry| entry.fetch('event_type') }
    )
  end

  it 'stores invalid result and moves file to invalid' do
    processing_path = File.join(workspace.path_for(:processing), 'task-2.json')
    File.write(
      processing_path,
      JSON.pretty_generate(fixture_json('runtime', 'invalid_input_missing_operation_kind.json'))
    )

    result = processor_class.new(
      config,
      processing_path:,
      runtime: {
        workspace:,
        audit_log:,
        clock:,
        transport_id_generator: -> { transport_id }
      }
    ).call

    assert_equal 'invalid', result[:result_kind]
    assert_path_exists File.join(workspace.path_for(:invalid), 'task-2.json')
    result_path = File.join(workspace.path_for(:results), 'task-2.json.result.json')

    assert_equal 'invalid', JSON.parse(File.read(result_path)).fetch('result_kind')
  end

  it 're-raises retryable failures on first attempt and keeps file in processing' do
    processing_path = File.join(workspace.path_for(:processing), 'task-3.json')
    File.write(processing_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))

    error = assert_raises(StandardError) do
      with_singleton_stub(
        P1Tool::Application::Dispatcher,
        :call_with_config,
        ->(_input, config:) { raise StandardError, 'boom' }
      ) do
        processor_class.new(
          config,
          processing_path:,
          attempt: 1,
          correlation_id: 'job-1',
          runtime: {
            workspace:,
            audit_log:,
            clock:,
            transport_id_generator: -> { transport_id }
          }
        ).call
      end
    end

    assert_equal 'boom', error.message
    assert_path_exists processing_path
    refute_path_exists File.join(workspace.path_for(:done), 'task-3.json')
    refute_path_exists File.join(workspace.path_for(:results), 'task-3.json.result.json')
  end

  it 'stores terminal failure on second attempt and moves file to done' do
    processing_path = File.join(workspace.path_for(:processing), 'task-4.json')
    File.write(processing_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))

    result = with_singleton_stub(
      P1Tool::Application::Dispatcher,
      :call_with_config,
      ->(_input, config:) { raise StandardError, 'boom' }
    ) do
      processor_class.new(
        config,
        processing_path:,
        attempt: 2,
        correlation_id: 'job-1',
        runtime: {
          workspace:,
          audit_log:,
          clock:,
          transport_id_generator: -> { transport_id }
        }
      ).call
    end

    assert_equal 'failure', result[:result_kind]
    assert_equal 'technical', result.dig(:error, :category)
    assert_equal 2, result[:attempt]
    assert_equal 'register-encounter-task-1', result[:task_id]
    assert_equal 'register_encounter', result[:operation_kind]
    assert_path_exists File.join(workspace.path_for(:done), 'task-4.json')
    result_path = File.join(workspace.path_for(:results), 'task-4.json.result.json')

    persisted_result = JSON.parse(File.read(result_path))

    assert_equal 'failure', persisted_result.fetch('result_kind')
    assert_equal 'register-encounter-task-1', persisted_result.fetch('task_id')
    assert_equal 'register_encounter', persisted_result.fetch('operation_kind')
  end
end
