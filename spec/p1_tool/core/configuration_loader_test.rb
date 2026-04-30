# frozen_string_literal: true

require_relative "../../test_helper"

class P1ToolConfigurationLoaderTest < Minitest::Test
  def test_load_returns_symbolized_config_hash
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      File.write(config_path, valid_config)

      config = P1Tool::Core::ConfigurationLoader.load(config_path)

      assert_equal "/data/inbox", config.dig(:paths, :inbox)
      assert_equal false, config.dig(:subject, :is_practice)
      assert_equal "SIGNING_CERT_PASSWORD", config.dig(:certificates, :signing, :password_env)
    end
  end

  def test_load_raises_for_missing_required_keys
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      File.write(config_path, invalid_config)

      error = assert_raises(P1Tool::ConfigurationError) do
        P1Tool::Core::ConfigurationLoader.load(config_path)
      end

      assert_match("Config validation failed", error.message)
      assert_equal ["is missing"], error.details.dig(:paths, :processing)
      assert_equal ["is missing"], error.details[:redis]
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

  def invalid_config
    <<~YAML
      paths:
        inbox: /data/inbox
        done: /data/done
        invalid: /data/invalid
        results: /data/results
        audit_log: /logs/audit.jsonl
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
