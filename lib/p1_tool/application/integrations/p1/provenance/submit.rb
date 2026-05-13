# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Provenance
          class Submit < CreateOrUpdateSubmit
            RESOURCE_TYPE = 'Provenance'
            SUBMISSION_EVENT_TYPE = 'p1_provenance_submitted'
            SUBMISSION_ACTION = 'submit_provenance_to_p1'

            def initialize(xml:, provenance_data:, client:)
              super(xml:, resource_data: provenance_data, client:)
            end
          end
        end
      end
    end
  end
end
