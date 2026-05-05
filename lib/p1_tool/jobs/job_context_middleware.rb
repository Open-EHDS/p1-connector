# frozen_string_literal: true

module P1Tool
  module Jobs
    class JobContextMiddleware
      def call(_worker, job, _queue, &)
        P1Tool::Jobs::CurrentJob.with(job, &)
      end
    end
  end
end
