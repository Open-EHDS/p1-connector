# frozen_string_literal: true

require_relative "../../test_helper"

class P1ToolCliTest < Minitest::Test
  def test_help_lists_verify_config_option
    stdout = StringIO.new
    stderr = StringIO.new

    exit_code = P1Tool::CLI.start([], stdout: stdout, stderr: stderr)

    assert_equal 0, exit_code
    assert_includes stdout.string, "run-once --input PATH --output PATH [--config PATH]"
    assert_includes stdout.string, "verify [--config PATH]"
    assert_empty stderr.string
  end

  def test_run_once_processes_valid_input_file
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      input_path = File.join(dir, "input.json")
      output_path = File.join(dir, "results", "output.json")

      write_runtime_config(config_path, audit_log: File.join(dir, "audit", "audit.jsonl"))
      File.write(input_path, JSON.pretty_generate(fixture_json("runtime", "valid_input.json")))

      stdout = StringIO.new
      stderr = StringIO.new

      exit_code = P1Tool::CLI.start(
        ["run-once", "--config", config_path, "--input", input_path, "--output", output_path],
        stdout: stdout,
        stderr: stderr
      )

      assert_equal 0, exit_code
      assert_includes stdout.string, "Execution finished with success"
      assert_equal "success", JSON.parse(File.read(output_path)).fetch("result_kind")
      assert_empty stderr.string
    end
  end

  def test_run_once_returns_non_zero_for_invalid_input
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      input_path = File.join(dir, "input.json")
      output_path = File.join(dir, "results", "output.json")

      write_runtime_config(config_path, audit_log: File.join(dir, "audit", "audit.jsonl"))
      File.write(
        input_path,
        JSON.pretty_generate(fixture_json("runtime", "invalid_input_missing_operation_kind.json"))
      )

      stdout = StringIO.new
      stderr = StringIO.new

      exit_code = P1Tool::CLI.start(
        ["run-once", "--config", config_path, "--input", input_path, "--output", output_path],
        stdout: stdout,
        stderr: stderr
      )

      assert_equal 1, exit_code
      assert_includes stdout.string, "Execution finished with invalid"
      assert_equal "invalid", JSON.parse(File.read(output_path)).fetch("result_kind")
      assert_empty stderr.string
    end
  end

  def test_verify_loads_and_validates_config
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      write_runtime_config(config_path)

      stdout = StringIO.new
      stderr = StringIO.new

      exit_code = P1Tool::CLI.start(
        ["verify", "--config", config_path],
        stdout: stdout,
        stderr: stderr
      )

      assert_equal 0, exit_code
      assert_includes stdout.string, "Configuration OK"
      assert_includes stdout.string, File.expand_path(config_path)
      assert_empty stderr.string
    end
  end

  def test_verify_reports_configuration_errors
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      write_config_fixture(
        config_path,
        fixture_name: "invalid_runtime_config_missing_required.yml",
        replacements: { "__AUDIT_LOG_PATH__" => "/logs/audit.jsonl" }
      )

      stdout = StringIO.new
      stderr = StringIO.new

      exit_code = P1Tool::CLI.start(
        ["verify", "--config", config_path],
        stdout: stdout,
        stderr: stderr
      )

      assert_equal 1, exit_code
      assert_empty stdout.string
      assert_includes stderr.string, "Configuration error:"
      assert_includes stderr.string, "paths.processing"
    end
  end

  private

  def write_runtime_config(config_path, audit_log: "/logs/audit.jsonl")
    write_config_fixture(
      config_path,
      fixture_name: "runtime_config.yml",
      replacements: { "__AUDIT_LOG_PATH__" => audit_log }
    )
  end
end
