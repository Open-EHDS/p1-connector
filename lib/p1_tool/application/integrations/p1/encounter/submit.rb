# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Encounter
          class Submit < CreateOrUpdateSubmit
            RESOURCE_TYPE = 'Encounter'
            SUBMISSION_EVENT_TYPE = 'p1_encounter_submitted'
            SUBMISSION_ACTION = 'submit_encounter_to_p1'

            def initialize(xml:, encounter_data:, client:)
              super(xml:, resource_data: encounter_data, client:)
            end
          end
        end
      end
    end
  end
end
