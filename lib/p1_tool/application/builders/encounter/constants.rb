# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module Encounter
        class Constants
          include P1Tool::Application::Builders::SharedConstants

          PROFILE = 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLMedicalEvent'
          ENCOUNTER_CLASS_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.11.1.34'
          PL_PAYOR_REFERENCE_EXTENSION = 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLPayorReference'
          DEFAULT_STATUS = 'finished'

          PROFESSION_NUMBERS = {
            'LEK' => '11',
            'LEKD' => '12',
            'HIGSZKOL' => '7',
            'DIAG' => '2',
            'FIZJO' => '6'
          }.freeze

          DEFAULT_CLASS_CODES = {
            'LEK' => { code: '4', display: 'Porada' },
            'LEKD' => { code: '4', display: 'Porada' },
            'HIGSZKOL' => { code: '6', display: 'Wizyta' },
            'FIZJO' => { code: '6', display: 'Wizyta' },
            'DIAG' => { code: '9', display: 'Badanie' }
          }.freeze

          class << self
            def supported_profession_codes
              PROFESSION_NUMBERS.keys
            end

            def profession_number_for(profession_code)
              PROFESSION_NUMBERS[profession_code]
            end

            def default_class_for(profession_code)
              DEFAULT_CLASS_CODES[profession_code]
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
