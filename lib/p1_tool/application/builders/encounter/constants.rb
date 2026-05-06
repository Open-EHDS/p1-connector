# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module Encounter
        class Constants
          DOCTOR_NPWZ_IDENTIFICATION_SYSTEM = '2.16.840.1.113883.3.4424.1.6.2'
          PATIENT_PESEL_IDENTIFICATION_SYSTEM = '2.16.840.1.113883.3.4424.1.1.616'
          DOCTOR_PROFESSION_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.11.1.80'
          PROFILE = 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLMedicalEvent'
          SECURITY_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.11.1.83'
          ENCOUNTER_CLASS_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.11.1.34'
          PRACTICE_SYSTEM_PREFIX = 'urn:oid:2.16.840.1.113883.3.4424.2.4.'
          ENTITY_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.2.3.1'
          ENTITY_LOCATION_UNIT_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.2.3.2'
          ENTITY_LOCATION_CELL_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.2.3.3'
          PL_FUNCTION_EXTENSION = 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLFunction'
          PL_PAYOR_REFERENCE_EXTENSION = 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLPayorReference'
          DEFAULT_STATUS = 'finished'
          DEFAULT_SECURITY_CODE = 'N'

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
              "urn:oid:#{PATIENT_PESEL_IDENTIFICATION_SYSTEM}"
            end
          end
        end
      end
    end
  end
end
