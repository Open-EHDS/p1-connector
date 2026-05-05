# frozen_string_literal: true

require_relative '../../test_helper'
require 'yaml'

describe P1Tool::Runtime::ContinuousRunner do
  let(:runner_class) { P1Tool::Runtime::ContinuousRunner }
  let(:tmpdir) { Dir.mktmpdir }
  let(:config_path) { File.join(tmpdir, 'config.yml') }
  let(:stdout) { StringIO.new }
  let(:audit_log_path) { File.join(tmpdir, 'logs', 'audit.jsonl') }

  before do
    config = runtime_config_for(tmpdir, audit_log_path:)
    File.write(config_path, YAML.dump(JSON.parse(JSON.generate(config))))
  end

  after do
    P1Tool::Runtime::RuntimeEnvironment.reset!
    FileUtils.rm_rf(tmpdir)
  end

  it 'runs recovery before starting embedded sidekiq' do
    recovery_called = false
    embedded_run_called = false
    embedded = Object.new
    embedded.define_singleton_method(:run) { embedded_run_called = true }
    embedded.define_singleton_method(:stop) { true }

    recovery = Object.new
    recovery.define_singleton_method(:call) do
      recovery_called = true
      []
    end

    configure_embed = lambda do
      embedded
    end

    with_singleton_stub(P1Tool::Runtime::ProcessingRecovery, :new, ->(_workspace) { recovery }) do
      with_singleton_stub(Sidekiq, :configure_embed, configure_embed) do
        runner = runner_class.new(config_path:, stdout:)
        runner.define_singleton_method(:install_signal_handlers) { |_embedded| nil }
        runner.define_singleton_method(:sleep) { raise Interrupt }

        runner.run
      rescue Interrupt
        nil
      end
    end

    assert recovery_called
    assert embedded_run_called
  end
end
