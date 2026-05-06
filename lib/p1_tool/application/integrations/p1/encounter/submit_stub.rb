# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Encounter
          class SubmitStub
            def initialize(xml:, encounter_data:, patient_result:, subject:)
              @xml = xml
              @encounter_data = encounter_data
              @patient_result = patient_result
              @subject = subject
            end

            def call
              { status: 'stubbed', action: 'submit_encounter_to_p1', submitted: false }
            end

            private

            attr_reader :xml, :encounter_data, :patient_result, :subject
          end
        end
      end
    end
  end
end
