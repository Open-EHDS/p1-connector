# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Runtime::Workspace do
  let(:workspace_class) { P1Tool::Runtime::Workspace }
  let(:tmpdir) { Dir.mktmpdir }
  let(:workspace_config) do
    {
      paths: {
        inbox: File.join(tmpdir, 'inbox'),
        processing: File.join(tmpdir, 'processing'),
        done: File.join(tmpdir, 'done'),
        invalid: File.join(tmpdir, 'invalid'),
        results: File.join(tmpdir, 'results'),
        audit_log: File.join(tmpdir, 'logs', 'audit.jsonl')
      }
    }
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe '#prepare!' do
    it 'creates working directories' do
      workspace = workspace_class.new(workspace_config)

      workspace.prepare!

      %i[inbox processing done invalid results].each do |key|
        assert Dir.exist?(workspace.path_for(key)), "expected #{key} directory to exist"
      end
    end
  end

  describe '#claim_inbox_file' do
    it 'moves file to processing' do
      workspace = workspace_class.new(workspace_config)
      workspace.prepare!

      inbox_path = File.join(workspace.path_for(:inbox), 'task-1.json')
      File.write(inbox_path, "{\"task_id\":\"1\"}\n")

      claimed_path = workspace.claim_inbox_file(inbox_path)

      assert_equal File.join(workspace.path_for(:processing), 'task-1.json'), claimed_path
      refute_path_exists inbox_path
      assert_equal "{\"task_id\":\"1\"}\n", File.read(claimed_path)
    end
  end

  describe '#processing_files' do
    it 'lists files in processing directory' do
      workspace = workspace_class.new(workspace_config)
      workspace.prepare!

      first_path = File.join(workspace.path_for(:processing), 'task-1.json')
      second_path = File.join(workspace.path_for(:processing), 'task-2.json')
      File.write(first_path, "{\"task_id\":\"1\"}\n")
      File.write(second_path, "{\"task_id\":\"2\"}\n")

      assert_equal [first_path, second_path], workspace.processing_files
    end
  end

  describe '#write_result' do
    it 'stores result json in results directory' do
      workspace = workspace_class.new(workspace_config)
      workspace.prepare!

      processing_path = File.join(workspace.path_for(:processing), 'task-1.json')
      File.write(processing_path, "{\"task_id\":\"1\"}\n")

      result_path = workspace.write_result(processing_path, {
                                             transport_id: 'transport-1',
                                             task_id: 'task-1',
                                             operation_kind: 'hello_world',
                                             result_kind: 'success',
                                             attempt: 1,
                                             started_at: '2026-04-30T10:00:00Z',
                                             finished_at: '2026-04-30T10:00:01Z'
                                           })

      assert_equal File.join(workspace.path_for(:results), 'task-1.json.result.json'), result_path
      assert_equal 'success', JSON.parse(File.read(result_path)).fetch('result_kind')
    end
  end

  describe '#move_to_done' do
    it 'moves file out of processing' do
      workspace = workspace_class.new(workspace_config)
      workspace.prepare!

      processing_path = File.join(workspace.path_for(:processing), 'task-1.json')
      File.write(processing_path, "{\"task_id\":\"1\"}\n")

      destination_path = workspace.move_to_done(processing_path)

      assert_equal File.join(workspace.path_for(:done), 'task-1.json'), destination_path
      refute_path_exists processing_path
      assert_path_exists destination_path
    end
  end

  describe '#move_to_invalid' do
    it 'moves file out of processing' do
      workspace = workspace_class.new(workspace_config)
      workspace.prepare!

      processing_path = File.join(workspace.path_for(:processing), 'task-2.json')
      File.write(processing_path, "{\"task_id\":\"2\"}\n")

      destination_path = workspace.move_to_invalid(processing_path)

      assert_equal File.join(workspace.path_for(:invalid), 'task-2.json'), destination_path
      refute_path_exists processing_path
      assert_path_exists destination_path
    end
  end

  describe '#recover_processing_file' do
    it 'moves file from processing back to inbox' do
      workspace = workspace_class.new(workspace_config)
      workspace.prepare!

      processing_path = File.join(workspace.path_for(:processing), 'task-3.json')
      File.write(processing_path, "{\"task_id\":\"3\"}\n")

      destination_path = workspace.recover_processing_file(processing_path)

      assert_equal File.join(workspace.path_for(:inbox), 'task-3.json'), destination_path
      refute_path_exists processing_path
      assert_path_exists destination_path
    end
  end
end
