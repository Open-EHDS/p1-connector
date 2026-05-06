# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Patient
          class FindOrCreateStub
            def initialize(payload:, subject:)
              @payload = payload
              @subject = subject
            end

            def call
              {
                status: 'stubbed',
                action: 'find_or_create_patient',
                patient_reference_id: "stub-patient-#{payload.dig(:patient, :pesel)}"
              }
            end

            private

            attr_reader :payload, :subject
          end
        end
      end
    end
  end
end
