# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Condition
          class Submit < CreateOrUpdateSubmit
            RESOURCE_TYPE = 'Condition'
            SUBMISSION_EVENT_TYPE = 'p1_condition_submitted'
            SUBMISSION_ACTION = 'submit_condition_to_p1'
          end
        end
      end
    end
  end
end
