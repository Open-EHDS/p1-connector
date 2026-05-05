# frozen_string_literal: true

require 'sidekiq'

module P1Tool
  module Jobs
    class InboxScanJob
      include Sidekiq::Job

      sidekiq_options queue: 'continuous', retry: false

      def perform
        workspace = P1Tool::Runtime::RuntimeEnvironment.workspace

        workspace.inbox_files.each do |inbox_path|
          processing_path = workspace.claim_inbox_file(inbox_path)
          next if processing_path.nil?

          P1Tool::Jobs::ProcessTaskJob.perform_async(processing_path)
        end
      end
    end
  end
end
