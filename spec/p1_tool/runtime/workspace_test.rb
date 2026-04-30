# frozen_string_literal: true

require_relative "../../test_helper"

class P1ToolWorkspaceTest < Minitest::Test
  def test_prepare_creates_working_directories
    Dir.mktmpdir do |dir|
      workspace = P1Tool::Runtime::Workspace.new(workspace_config(dir))

      workspace.prepare!

      %i[inbox processing done invalid results].each do |key|
        assert Dir.exist?(workspace.path_for(key)), "expected #{key} directory to exist"
      end
    end
  end

  def test_claim_inbox_file_moves_file_to_processing
    Dir.mktmpdir do |dir|
      workspace = P1Tool::Runtime::Workspace.new(workspace_config(dir))
      workspace.prepare!

      inbox_path = File.join(workspace.path_for(:inbox), "task-1.json")
      File.write(inbox_path, "{\"task_id\":\"1\"}\n")

      claimed_path = workspace.claim_inbox_file(inbox_path)

      assert_equal File.join(workspace.path_for(:processing), "task-1.json"), claimed_path
      refute File.exist?(inbox_path)
      assert_equal "{\"task_id\":\"1\"}\n", File.read(claimed_path)
    end
  end

  def test_write_result_stores_result_json_in_results_directory
    Dir.mktmpdir do |dir|
      workspace = P1Tool::Runtime::Workspace.new(workspace_config(dir))
      workspace.prepare!

      processing_path = File.join(workspace.path_for(:processing), "task-1.json")
      File.write(processing_path, "{\"task_id\":\"1\"}\n")

      result_path = workspace.write_result(processing_path, {
        transport_id: "transport-1",
        task_id: "task-1",
        operation_kind: "hello_world",
        result_kind: "success",
        attempt: 1,
        started_at: "2026-04-30T10:00:00Z",
        finished_at: "2026-04-30T10:00:01Z"
      })

      assert_equal File.join(workspace.path_for(:results), "task-1.json.result.json"), result_path
      assert_equal "success", JSON.parse(File.read(result_path)).fetch("result_kind")
    end
  end

  def test_move_to_done_moves_file_out_of_processing
    Dir.mktmpdir do |dir|
      workspace = P1Tool::Runtime::Workspace.new(workspace_config(dir))
      workspace.prepare!

      processing_path = File.join(workspace.path_for(:processing), "task-1.json")
      File.write(processing_path, "{\"task_id\":\"1\"}\n")

      destination_path = workspace.move_to_done(processing_path)

      assert_equal File.join(workspace.path_for(:done), "task-1.json"), destination_path
      refute File.exist?(processing_path)
      assert File.exist?(destination_path)
    end
  end

  def test_move_to_invalid_moves_file_out_of_processing
    Dir.mktmpdir do |dir|
      workspace = P1Tool::Runtime::Workspace.new(workspace_config(dir))
      workspace.prepare!

      processing_path = File.join(workspace.path_for(:processing), "task-2.json")
      File.write(processing_path, "{\"task_id\":\"2\"}\n")

      destination_path = workspace.move_to_invalid(processing_path)

      assert_equal File.join(workspace.path_for(:invalid), "task-2.json"), destination_path
      refute File.exist?(processing_path)
      assert File.exist?(destination_path)
    end
  end

  private

  def workspace_config(root_dir)
    {
      paths: {
        inbox: File.join(root_dir, "inbox"),
        processing: File.join(root_dir, "processing"),
        done: File.join(root_dir, "done"),
        invalid: File.join(root_dir, "invalid"),
        results: File.join(root_dir, "results"),
        audit_log: File.join(root_dir, "logs", "audit.jsonl")
      }
    }
  end
end
