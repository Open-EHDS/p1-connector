# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Jobs::ProcessTaskJob do
  let(:job_class) { P1Tool::Jobs::ProcessTaskJob }
  let(:tmpdir) { Dir.mktmpdir }
  let(:config) { runtime_config_for(tmpdir) }

  before do
    P1Tool::Runtime::RuntimeEnvironment.bootstrap!(config:)
  end

  after do
    P1Tool::Runtime::RuntimeEnvironment.reset!
    FileUtils.rm_rf(tmpdir)
  end

  it 'passes attempt 1 and jid to the processor for first execution' do
    processing_path = File.join(config.dig(:paths, :processing), 'task-1.json')
    received = {}
    processor = Object.new
    processor.define_singleton_method(:call) { true }

    with_singleton_stub(P1Tool::Runtime::ContinuousTaskProcessor, :new, lambda { |cfg, **kwargs|
      received[:config] = cfg
      received[:kwargs] = kwargs
      processor
    }) do
      P1Tool::Jobs::CurrentJob.with({ 'jid' => 'job-1' }) do
        job_class.new.perform(processing_path)
      end
    end

    assert_equal config, received.fetch(:config)
    assert_equal processing_path, received.dig(:kwargs, :processing_path)
    assert_equal 1, received.dig(:kwargs, :attempt)
    assert_equal 'job-1', received.dig(:kwargs, :correlation_id)
  end

  it 'passes attempt 2 and retry jid to the processor for retry execution' do
    processing_path = File.join(config.dig(:paths, :processing), 'task-2.json')
    received = {}
    processor = Object.new
    processor.define_singleton_method(:call) { true }

    with_singleton_stub(P1Tool::Runtime::ContinuousTaskProcessor, :new, lambda { |cfg, **kwargs|
      received[:config] = cfg
      received[:kwargs] = kwargs
      processor
    }) do
      P1Tool::Jobs::CurrentJob.with({ 'jid' => 'job-1', 'retry_count' => 0 }) do
        job_class.new.perform(processing_path)
      end
    end

    assert_equal config, received.fetch(:config)
    assert_equal processing_path, received.dig(:kwargs, :processing_path)
    assert_equal 2, received.dig(:kwargs, :attempt)
    assert_equal 'job-1', received.dig(:kwargs, :correlation_id)
  end
end
