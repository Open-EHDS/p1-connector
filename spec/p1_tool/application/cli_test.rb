# frozen_string_literal: true

require_relative "../../test_helper"

class P1ToolCliTest < Minitest::Test
  def test_help_lists_verify_config_option
    stdout = StringIO.new
    stderr = StringIO.new

    exit_code = P1Tool::CLI.start([], stdout: stdout, stderr: stderr)

    assert_equal 0, exit_code
    assert_includes stdout.string, "verify [--config PATH]"
    assert_empty stderr.string
  end

  def test_verify_loads_and_validates_config
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      File.write(config_path, valid_config)

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
      File.write(config_path, "paths:\n  inbox: /data/inbox\n")

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

  def valid_config
    <<~YAML
      paths:
        inbox: /data/inbox
        processing: /data/processing
        done: /data/done
        invalid: /data/invalid
        results: /data/results
        audit_log: /logs/audit.jsonl
      redis:
        url: redis://localhost:6379/0
      signature_service:
        url: http://localhost:8080
      subject:
        oid: "1.2.616.1.113883.3.4424.1.1"
        identification_code: "1234567890"
        department_code_v: "1234"
        department_code_vii: "1234567"
        is_practice: false
        medical_chamber: "NIL"
      certificates:
        base_path: /certs
        signing:
          filename: signing.p12
          password_env: SIGNING_CERT_PASSWORD
        tls:
          filename: tls.p12
          password_env: TLS_CERT_PASSWORD
    YAML
  end
end
