# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Runtime::RuntimeEnvironment do
  let(:runtime_environment) { P1Tool::Runtime::RuntimeEnvironment }
  let(:tmpdir) { Dir.mktmpdir }
  let(:config) { runtime_config_for(tmpdir) }

  after do
    runtime_environment.reset!
    FileUtils.rm_rf(tmpdir)
  end

  it 'keeps bootstrapped config and prepares workspace once per process' do
    runtime_environment.bootstrap!(config:)

    assert_equal config, runtime_environment.config
    assert_path_exists runtime_environment.workspace.path_for(:inbox)
    assert_equal config.dig(:paths, :audit_log), runtime_environment.audit_log.instance_variable_get(:@path)
  end
end
