# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Adapters::FileSystem do
  let(:file_system) { P1Tool::Adapters::FileSystem.new }

  describe '#read' do
    it 'reads file content' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'input.json')
        File.write(path, "{}\n")

        assert_equal "{}\n", file_system.read(path)
      end
    end
  end

  describe '#append_line' do
    it 'creates parent directory and appends one line' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'logs', 'audit.jsonl')

        file_system.append_line(path, '{"event":"started"}')
        file_system.append_line(path, '{"event":"finished"}')

        assert_equal [
          '{"event":"started"}',
          '{"event":"finished"}'
        ], File.readlines(path, chomp: true)
      end
    end
  end

  describe '#atomic_write' do
    it 'replaces file via temp file' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'result.json')
        File.write(path, "old\n")

        file_system.atomic_write(path, "new\n")

        assert_equal "new\n", File.read(path)
        refute(Dir.children(dir).any? { |entry| entry.start_with?('.tmp-result.json-') })
      end
    end
  end

  describe '#atomic_move' do
    it 'returns nil when source was already claimed' do
      Dir.mktmpdir do |dir|
        source_path = File.join(dir, 'task.json')
        destination_path = File.join(dir, 'claimed.json')
        File.write(source_path, '{}')

        file_system.atomic_move(source_path, destination_path)

        assert_nil file_system.atomic_move(source_path, File.join(dir, 'claimed-again.json'))
      end
    end
  end
end
