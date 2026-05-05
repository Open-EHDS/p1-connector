# frozen_string_literal: true

module P1Tool
  module Runtime
    class ProcessingRecovery
      def initialize(workspace)
        @workspace = workspace
      end

      def call
        @workspace.processing_files.filter_map do |processing_path|
          recover_file(processing_path)
        end
      end

      private

      def recover_file(processing_path)
        inbox_path = @workspace.recover_processing_file(processing_path)
        return nil if inbox_path.nil?

        {
          from: processing_path,
          to: inbox_path
        }
      end
    end
  end
end
