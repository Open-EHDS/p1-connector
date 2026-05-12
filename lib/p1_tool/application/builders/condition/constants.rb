# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module Condition
        class Constants
          include P1Tool::Application::Builders::SharedConstants

          PROFILE = 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLMedicalEventDiagnosis'
          LOCATION_EXTENSION = 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLLocation'
          CONDITION_CATEGORY_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.11.1.78'
          CONDITION_CATEGORIES = {
            'main' => 'Główne',
            'concurrent' => 'Współistniejące'
          }.freeze
          DEFAULT_CONDITION_CATEGORY_CODE = 'main'
          ICD_10_CODE_SYSTEM = 'urn:oid:2.16.840.1.113883.6.3'
          ENCOUNTER_CONSTANTS = P1Tool::Application::Builders::Encounter::Constants

          class << self
            def supported_profession_codes
              ENCOUNTER_CONSTANTS.supported_profession_codes
            end

            def supported_condition_category_codes
              CONDITION_CATEGORIES.keys
            end

            def condition_category_display_for(code)
              CONDITION_CATEGORIES.fetch(code)
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
