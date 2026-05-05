# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Runtime::ProcessingRecovery do
  let(:recovery_class) { P1Tool::Runtime::ProcessingRecovery }
  let(:tmpdir) { Dir.mktmpdir }
  let(:config) { runtime_config_for(tmpdir) }
  let(:workspace) { P1Tool::Runtime::Workspace.new(config) }

  before do
    workspace.prepare!
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  it 'moves all files from processing to inbox' do
    first_path = File.join(workspace.path_for(:processing), 'task-1.json')
    second_path = File.join(workspace.path_for(:processing), 'task-2.json')
    File.write(first_path, "{\"task_id\":\"1\"}\n")
    File.write(second_path, "{\"task_id\":\"2\"}\n")

    recovered_files = recovery_class.new(workspace).call
    recovered_from_paths = recovered_files.map { |entry| entry.fetch(:from) }

    assert_equal 2, recovered_files.size
    assert_equal [first_path, second_path], recovered_from_paths
    assert_equal(
      [
        File.join(workspace.path_for(:inbox), 'task-1.json'),
        File.join(workspace.path_for(:inbox), 'task-2.json')
      ],
      recovered_files.map { |entry| entry.fetch(:to) }
    )
    assert_empty workspace.processing_files
  end

  it 'returns empty result when processing is empty' do
    assert_equal [], recovery_class.new(workspace).call
  end
end
