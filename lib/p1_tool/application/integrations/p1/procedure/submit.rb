# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Procedure
          class Submit < CreateOrUpdateSubmit
            RESOURCE_TYPE = 'Procedure'
            SUBMISSION_EVENT_TYPE = 'p1_procedure_submitted'
            SUBMISSION_ACTION = 'submit_procedure_to_p1'
          end
        end
      end
    end
  end
end
