# frozen_string_literal: true

require_relative "../../test_helper"

class P1ToolFileSystemTest < Minitest::Test
  def test_atomic_write_replaces_file_via_temp_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "result.json")
      File.write(path, "old\n")

      P1Tool::Adapters::FileSystem.new.atomic_write(path, "new\n")

      assert_equal "new\n", File.read(path)
      refute Dir.children(dir).any? { |entry| entry.start_with?(".tmp-result.json-") }
    end
  end

  def test_atomic_move_returns_nil_when_source_was_already_claimed
    Dir.mktmpdir do |dir|
      source_path = File.join(dir, "task.json")
      destination_path = File.join(dir, "claimed.json")
      File.write(source_path, "{}")

      file_system = P1Tool::Adapters::FileSystem.new
      file_system.atomic_move(source_path, destination_path)

      assert_nil file_system.atomic_move(source_path, File.join(dir, "claimed-again.json"))
    end
  end
end
