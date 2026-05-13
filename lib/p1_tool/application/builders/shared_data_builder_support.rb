# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module SharedDataBuilderSupport
        private

        def patient_name(patient)
          [patient[:first_name], patient[:last_name]].join(' ')
        end

        def doctor_identifier_system(doctor)
          base =
            if blank?(doctor[:npwz])
              constants::PATIENT_PESEL_IDENTIFICATION_SYSTEM
            else
              constants::DOCTOR_NPWZ_IDENTIFICATION_SYSTEM
            end

          "urn:oid:#{base}"
        end

        def doctor_identifier_value(doctor)
          doctor[:npwz] || doctor[:pesel]
        end

        def subject_provider_system
          return "#{constants::PRACTICE_SYSTEM_PREFIX}#{subject.fetch(:medical_chamber)}" if subject.fetch(:is_practice)

          constants::ENTITY_SYSTEM
        end

        def subject_location_system
          return "#{subject_provider_system}.1" if subject.fetch(:is_practice)
          return constants::ENTITY_LOCATION_CELL_SYSTEM if present?(subject[:department_code_vii])

          constants::ENTITY_LOCATION_UNIT_SYSTEM
        end

        def subject_location_value
          return subject.fetch(:identification_code) if subject.fetch(:is_practice)

          "#{subject.fetch(:identification_code)}-#{subject_department_code}"
        end

        def subject_department_code
          department_code_vii = subject[:department_code_vii]
          return department_code_vii.strip if present?(department_code_vii)

          subject[:department_code_v]&.strip
        end

        def blank?(value)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end

        def present?(value)
          !blank?(value)
        end
      end
    end
  end
end
