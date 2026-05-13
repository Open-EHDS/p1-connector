# frozen_string_literal: true

require 'json'

module P1Tool
  module Runtime
    class Workspace
      DIRECTORY_KEYS = %i[inbox processing done invalid results].freeze

      def initialize(config, file_system: P1Tool::Adapters::FileSystem.new)
        @config = config
        @file_system = file_system
      end

      attr_reader :file_system

      def prepare!
        directory_paths.each_value { |path| @file_system.mkdir_p(path) }
      end

      def inbox_files
        @file_system.regular_files(path_for(:inbox))
      end

      def processing_files
        @file_system.regular_files(path_for(:processing))
      end

      def claim_inbox_file(inbox_path)
        @file_system.atomic_move(inbox_path, processing_path_for(inbox_path))
      end

      def recover_processing_file(processing_path)
        @file_system.atomic_move(processing_path, destination_path_for(:inbox, processing_path))
      end

      def write_result(processing_path, result)
        result_path = File.join(path_for(:results), "#{File.basename(processing_path)}.result.json")
        payload = "#{JSON.pretty_generate(result)}\n"

        @file_system.atomic_write(result_path, payload)
      end

      def move_to_done(processing_path)
        @file_system.atomic_move(processing_path, destination_path_for(:done, processing_path))
      end

      def move_to_invalid(processing_path)
        @file_system.atomic_move(processing_path, destination_path_for(:invalid, processing_path))
      end

      def path_for(key)
        @config.fetch(:paths).fetch(key)
      end

      private

      def directory_paths
        DIRECTORY_KEYS.to_h { |key| [key, path_for(key)] }
      end

      def processing_path_for(source_path)
        destination_path_for(:processing, source_path)
      end

      def destination_path_for(directory_key, source_path)
        File.join(path_for(directory_key), File.basename(source_path))
      end
    end
  end
end
