# frozen_string_literal: true

require_relative "../../test_helper"

class P1ToolConfigurationLoaderTest < Minitest::Test
  def test_load_returns_symbolized_config_hash
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      write_config_fixture(
        config_path,
        fixture_name: "runtime_config.yml",
        replacements: { "__AUDIT_LOG_PATH__" => "/logs/audit.jsonl" }
      )

      config = P1Tool::Core::ConfigurationLoader.load(config_path)

      assert_equal "/data/inbox", config.dig(:paths, :inbox)
      assert_equal false, config.dig(:subject, :is_practice)
      assert_equal "SIGNING_CERT_PASSWORD", config.dig(:certificates, :signing, :password_env)
    end
  end

  def test_load_raises_for_missing_required_keys
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      write_config_fixture(
        config_path,
        fixture_name: "invalid_runtime_config_missing_required.yml",
        replacements: { "__AUDIT_LOG_PATH__" => "/logs/audit.jsonl" }
      )

      error = assert_raises(P1Tool::ConfigurationError) do
        P1Tool::Core::ConfigurationLoader.load(config_path)
      end

      assert_match("Config validation failed", error.message)
      assert_equal ["is missing"], error.details.dig(:paths, :processing)
      assert_equal ["is missing"], error.details[:redis]
    end
  end
end
