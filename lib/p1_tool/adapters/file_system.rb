# frozen_string_literal: true

require "fileutils"
require "securerandom"

module P1Tool
  module Adapters
    class FileSystem
      def mkdir_p(path)
        FileUtils.mkdir_p(path)
      end

      def regular_files(path)
        Dir.children(path).sort.filter_map do |entry|
          file_path = File.join(path, entry)
          file_path if File.file?(file_path)
        end
      end

      def atomic_move(source_path, destination_path)
        File.rename(source_path, destination_path)
        destination_path
      rescue Errno::ENOENT
        return nil unless File.exist?(source_path)

        raise
      end

      def atomic_write(path, content)
        directory = File.dirname(path)
        mkdir_p(directory)
        tmp_path = File.join(directory, ".tmp-#{File.basename(path)}-#{Process.pid}-#{SecureRandom.hex(6)}")

        File.write(tmp_path, content)
        File.rename(tmp_path, path)
        path
      ensure
        FileUtils.rm_f(tmp_path) if defined?(tmp_path)
      end
    end
  end
end
