# frozen_string_literal: true

require_relative "../../test_helper"

class P1ToolTaskProcessorTest < Minitest::Test
  def test_call_processes_valid_input_end_to_end
    Dir.mktmpdir do |dir|
      input_path = File.join(dir, "input.json")
      output_path = File.join(dir, "results", "output.json")
      audit_log_path = File.join(dir, "logs", "audit.jsonl")

      File.write(input_path, JSON.pretty_generate(fixture_json("runtime", "valid_input.json")))

      processor = build_processor(
        config: runtime_config(audit_log_path),
        input_path: input_path,
        output_path: output_path,
        at: "2026-04-30T10:00:00Z",
        transport_id: "transport-1"
      )

      result = processor.call

      assert_equal "success", result[:result_kind]
      assert_equal "transport-1", result[:transport_id]
      assert_equal "task-1", result[:task_id]
      assert_equal "hello_world", result[:operation_kind]
      assert_equal "hello world", result.dig(:details, :message)

      persisted_result = JSON.parse(File.read(output_path))
      assert_equal "success", persisted_result.fetch("result_kind")
      assert_equal "transport-1", persisted_result.fetch("transport_id")
      assert persisted_result.key?("config_version")

      audit_lines = File.readlines(audit_log_path, chomp: true).map { |line| JSON.parse(line) }
      assert_equal ["execution_started", "execution_finished"], audit_lines.map { |entry| entry.fetch("event_type") }
      assert_equal "success", audit_lines.last.fetch("result")
    end
  end

  def test_call_persists_invalid_result_for_invalid_input
    Dir.mktmpdir do |dir|
      input_path = File.join(dir, "input.json")
      output_path = File.join(dir, "results", "output.json")
      audit_log_path = File.join(dir, "logs", "audit.jsonl")

      File.write(
        input_path,
        JSON.pretty_generate(fixture_json("runtime", "invalid_input_missing_operation_kind.json"))
      )

      processor = build_processor(
        config: runtime_config(audit_log_path),
        input_path: input_path,
        output_path: output_path,
        at: "2026-04-30T10:00:00Z",
        transport_id: "transport-1"
      )

      result = processor.call

      assert_equal "invalid", result[:result_kind]
      assert_equal "invalid_input", result.dig(:error, :code)
      assert_equal "input", result.dig(:error, :category)
      assert_equal({ validation_errors: { operation_kind: ["is missing"] } }, result[:details])

      persisted_result = JSON.parse(File.read(output_path))
      assert_equal "invalid", persisted_result.fetch("result_kind")
      assert_equal "invalid_input", persisted_result.fetch("error").fetch("code")

      audit_lines = File.readlines(audit_log_path, chomp: true).map { |line| JSON.parse(line) }
      assert_equal ["execution_started", "execution_error", "execution_finished"], audit_lines.map { |entry| entry.fetch("event_type") }
      assert_equal "invalid", audit_lines[1].fetch("result")
      assert_equal "invalid", audit_lines[2].fetch("result")
    end
  end

  private

  def build_processor(config:, input_path:, output_path:, at:, transport_id:)
    clock = sequence_clock(at)

    P1Tool::Runtime::TaskProcessor.new(
      config,
      input_path: input_path,
      output_path: output_path,
      clock: clock,
      transport_id_generator: -> { transport_id }
    )
  end

  def runtime_config(audit_log_path)
    config_path = File.join(File.dirname(audit_log_path), "runtime_config.yml")
    write_config_fixture(
      config_path,
      fixture_name: "runtime_config.yml",
      replacements: { "__AUDIT_LOG_PATH__" => audit_log_path }
    )

    P1Tool::Core::ConfigurationLoader.load(config_path)
  end

  def sequence_clock(initial_time)
    times = [
      Time.iso8601(initial_time),
      Time.iso8601("2026-04-30T10:00:01Z")
    ]

    lambda do
      times.shift || Time.iso8601("2026-04-30T10:00:01Z")
    end
  end
end
