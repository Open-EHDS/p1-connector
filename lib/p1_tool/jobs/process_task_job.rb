# frozen_string_literal: true

require 'sidekiq'

module P1Tool
  module Jobs
    class ProcessTaskJob
      include Sidekiq::Job

      sidekiq_options queue: 'continuous', retry: 1

      sidekiq_retry_in do |_retry_count, _exception, _job|
        5
      end

      def perform(processing_path)
        P1Tool::Runtime::ContinuousTaskProcessor.new(
          P1Tool::Runtime::RuntimeEnvironment.config,
          processing_path: processing_path,
          attempt: current_attempt,
          correlation_id: current_jid
        ).call
      end

      private

      def current_attempt
        return 1 if current_job_payload.nil? || !current_job_payload.key?('retry_count')

        current_job_payload.fetch('retry_count').to_i + 2
      end

      def current_jid
        return jid if current_job_payload.nil?

        current_job_payload['jid'] || jid
      end

      def current_job_payload
        P1Tool::Jobs::CurrentJob.payload
      end
    end
  end
end
