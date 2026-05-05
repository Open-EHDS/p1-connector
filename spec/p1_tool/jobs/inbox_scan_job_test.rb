# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Jobs::InboxScanJob do
  let(:job_class) { P1Tool::Jobs::InboxScanJob }
  let(:tmpdir) { Dir.mktmpdir }
  let(:config) { runtime_config_for(tmpdir) }

  before do
    P1Tool::Runtime::RuntimeEnvironment.bootstrap!(config:)
  end

  after do
    P1Tool::Runtime::RuntimeEnvironment.reset!
    FileUtils.rm_rf(tmpdir)
  end

  it 'claims inbox files and enqueues processing jobs' do
    inbox_path = File.join(config.dig(:paths, :inbox), 'task-1.json')
    File.write(inbox_path, JSON.pretty_generate(fixture_json('runtime', 'valid_input.json')))

    enqueued = []

    with_singleton_stub(P1Tool::Jobs::ProcessTaskJob, :perform_async, ->(path) { enqueued << path }) do
      job_class.new.perform
    end

    assert_equal [File.join(config.dig(:paths, :processing), 'task-1.json')], enqueued
    assert_path_exists File.join(config.dig(:paths, :processing), 'task-1.json')
    refute_path_exists inbox_path
  end
end
