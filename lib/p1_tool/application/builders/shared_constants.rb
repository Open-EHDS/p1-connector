# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module SharedConstants
        DOCTOR_NPWZ_IDENTIFICATION_SYSTEM = '2.16.840.1.113883.3.4424.1.6.2'
        PATIENT_PESEL_IDENTIFICATION_SYSTEM = '2.16.840.1.113883.3.4424.1.1.616'
        DOCTOR_PROFESSION_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.11.1.80'
        SECURITY_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.11.1.83'
        PRACTICE_SYSTEM_PREFIX = 'urn:oid:2.16.840.1.113883.3.4424.2.4.'
        ENTITY_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.2.3.1'
        ENTITY_LOCATION_UNIT_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.2.3.2'
        ENTITY_LOCATION_CELL_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.2.3.3'
        PL_FUNCTION_EXTENSION = 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLFunction'
        DEFAULT_SECURITY_CODE = 'N'

        class << self
          def patient_pesel_system
            "urn:oid:#{PATIENT_PESEL_IDENTIFICATION_SYSTEM}"
          end
        end
      end
    end
  end
end
