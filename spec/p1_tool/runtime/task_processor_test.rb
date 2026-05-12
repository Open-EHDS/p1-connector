# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Runtime::TaskProcessor do
  let(:task_processor_class) { P1Tool::Runtime::TaskProcessor }
  let(:tmpdir) { Dir.mktmpdir }
  let(:input_path) { File.join(tmpdir, 'input.json') }
  let(:output_path) { File.join(tmpdir, 'results', 'output.json') }
  let(:audit_log_path) { File.join(tmpdir, 'logs', 'audit.jsonl') }
  let(:transport_id) { 'transport-1' }
  let(:started_time) { '2026-04-30T10:00:00Z' }
  let(:finished_time) { '2026-04-30T10:00:01Z' }
  let(:clock) do
    times = [
      Time.iso8601(started_time),
      Time.iso8601(finished_time)
    ]

    -> { times.shift || Time.iso8601(finished_time) }
  end
  let(:config) do
    config_path = File.join(File.dirname(audit_log_path), 'runtime_config.yml')
    write_config_fixture(
      config_path,
      fixture_name: 'runtime_config.yml',
      replacements: { '__AUDIT_LOG_PATH__' => audit_log_path }
    )

    with_stubbed_pkcs12_validation do
      P1Tool::Core::ConfigurationLoader.load(config_path)
    end
  end
  let(:processor) do
    task_processor_class.new(
      config,
      input_path: input_path,
      output_path: output_path,
      clock: clock,
      transport_id_generator: -> { transport_id }
    )
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe '#call' do
    it 'processes valid input end-to-end' do
      File.write(input_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))

      result = with_fake_p1_client_factory { processor.call }

      assert_equal 'success', result[:result_kind]
      assert_equal 'transport-1', result[:transport_id]
      assert_equal 'register-encounter-task-1', result[:task_id]
      assert_equal 'register_encounter', result[:operation_kind]
      assert_equal 'Encounter', result.dig(:details, :resource_type)
      assert_equal 'found', result.dig(:details, :patient_resolution, :status)
      refute result[:details].key?(:xml)

      persisted_result = JSON.parse(File.read(output_path))

      assert_equal 'success', persisted_result.fetch('result_kind')
      assert_equal 'transport-1', persisted_result.fetch('transport_id')
      assert persisted_result.key?('config_version')

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
      assert_equal 'success', audit_lines.last.fetch('result')
    end

    it 'persists invalid result for invalid input' do
      File.write(
        input_path,
        JSON.pretty_generate(fixture_json('runtime', 'invalid_input_missing_operation_kind.json'))
      )

      result = processor.call

      assert_equal 'invalid', result[:result_kind]
      assert_equal 'invalid_input', result.dig(:error, :code)
      assert_equal 'input', result.dig(:error, :category)
      assert_equal({ validation_errors: { operation_kind: ['is missing'] } }, result[:details])

      persisted_result = JSON.parse(File.read(output_path))

      assert_equal 'invalid', persisted_result.fetch('result_kind')
      assert_equal 'invalid_input', persisted_result.fetch('error').fetch('code')

      audit_lines = File.readlines(audit_log_path, chomp: true).map { |line| JSON.parse(line) }

      assert_equal(%w[execution_started execution_error execution_finished], audit_lines.map do |entry|
        entry.fetch('event_type')
      end)
      assert_equal 'invalid', audit_lines[1].fetch('result')
      assert_equal 'invalid', audit_lines[2].fetch('result')
    end

    it 'processes register encounter input without exposing XML in result details' do
      File.write(input_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))

      result = with_fake_p1_client_factory { processor.call }

      assert_equal 'success', result[:result_kind]
      assert_equal 'register_encounter', result[:operation_kind]
      assert_equal 'Encounter', result.dig(:details, :resource_type)
      assert_equal 'stub-patient-75061134485', result.dig(:details, :patient_reference_id)
      refute result[:details].key?(:xml)

      persisted_result = JSON.parse(File.read(output_path))

      assert_equal 'success', persisted_result.fetch('result_kind')
      assert_equal 'Encounter', persisted_result.fetch('details').fetch('resource_type')
      refute persisted_result.fetch('details').key?('xml')
    end

    it 'preserves task context in failure result after input validation succeeds' do
      File.write(input_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))

      result = with_singleton_stub(
        P1Tool::Application::Dispatcher,
        :call_with_config,
        ->(_input, config:) { raise StandardError, 'boom' }
      ) do
        processor.call
      end

      assert_equal 'failure', result[:result_kind]
      assert_equal 'register-encounter-task-1', result[:task_id]
      assert_equal 'register_encounter', result[:operation_kind]

      persisted_result = JSON.parse(File.read(output_path))

      assert_equal 'register-encounter-task-1', persisted_result.fetch('task_id')
      assert_equal 'register_encounter', persisted_result.fetch('operation_kind')
    end

    it 'persists structured upstream error details in failure result' do
      File.write(input_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))

      result = with_singleton_stub(
        P1Tool::Application::Dispatcher,
        :call_with_config,
        lambda do |_input, config:|
          raise P1Tool::BusinessError.new(
            'p1 failed',
            details: {
              http_status: 422,
              body: { 'issue' => [{ 'diagnostics' => 'invalid payload' }] }
            }
          )
        end
      ) do
        processor.call
      end

      assert_equal 'failure', result[:result_kind]
      assert_equal 422, result.dig(:error, :http_status)
      assert_equal [{ 'diagnostics' => 'invalid payload' }], result.dig(:error, :body, 'issue')

      persisted_result = JSON.parse(File.read(output_path))
      assert_equal 422, persisted_result.fetch('error').fetch('http_status')
      assert_equal [{ 'diagnostics' => 'invalid payload' }], persisted_result.fetch('error').dig('body', 'issue')

      audit_lines = File.readlines(audit_log_path, chomp: true).map { |line| JSON.parse(line) }
      error_entry = audit_lines.find { |entry| entry.fetch('event_type') == 'execution_error' }

      assert_equal 422, error_entry.dig('metadata', 'http_status')
      assert_equal [{ 'diagnostics' => 'invalid payload' }], error_entry.dig('metadata', 'body', 'issue')
    end
  end
end
