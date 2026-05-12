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

          class << self
            def supported_profession_codes
              P1Tool::Application::ReferenceData::PLMedicalEventStaffRole.all_codes
            end

            def resolve_medical_profession_code(doctor)
              explicit_code = doctor[:medical_profession_code]
              return explicit_code unless explicit_code.nil? || explicit_code.empty?

              mapped_medical_profession_code_for(doctor.fetch(:profession_code))
            end

            def mapped_medical_profession_code_for(profession_code)
              P1Tool::Application::ReferenceData::PLMedicalEventStaffRole.mapped_medical_profession_code_for(profession_code)
            end

            def supported_medical_profession_codes
              P1Tool::Application::ReferenceData::PLMedicalProfession.codes
            end

            def encounter_class_for(class_code)
              P1Tool::Application::ReferenceData::PLMedicalEventClass.fetch(class_code)
            end

            def supported_class_codes
              P1Tool::Application::ReferenceData::PLMedicalEventClass.codes
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
