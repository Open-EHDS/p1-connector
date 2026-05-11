# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module Procedure
        class Constants
          include P1Tool::Application::Builders::SharedConstants

          PROFILE = 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLMedicalEventProcedure'
          DEFAULT_STATUS = 'completed'
          PROCEDURE_CODE_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.11.2.6'
          ENCOUNTER_CONSTANTS = P1Tool::Application::Builders::Encounter::Constants

          class << self
            def supported_profession_codes
              ENCOUNTER_CONSTANTS.supported_profession_codes
            end

            def profession_number_for(profession_code)
              ENCOUNTER_CONSTANTS.profession_number_for(profession_code)
            end

            def patient_pesel_system
              P1Tool::Application::Builders::SharedConstants.patient_pesel_system
            end
          end
        end
      end
    end
  end
end
