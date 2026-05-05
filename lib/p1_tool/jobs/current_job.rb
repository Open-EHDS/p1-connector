# frozen_string_literal: true

module P1Tool
  module Jobs
    module CurrentJob
      THREAD_KEY = :p1_tool_current_sidekiq_job

      class << self
        def with(job_payload, &block)
          previous = Thread.current[THREAD_KEY]
          Thread.current[THREAD_KEY] = job_payload
          block.call
        ensure
          Thread.current[THREAD_KEY] = previous
        end

        def payload
          Thread.current[THREAD_KEY]
        end
      end
    end
  end
end
