# frozen_string_literal: true

require 'securerandom'

module P1Tool
  module Application
    module Builders
      module Encounter
        class DataBuilder
          def initialize(payload:, subject:, constants: Constants, id_generator: -> { SecureRandom.uuid })
            @payload = payload
            @subject = subject
            @constants = constants
            @id_generator = id_generator
          end

          def call
            encounter = payload.fetch(:encounter)
            doctor = payload.fetch(:doctor)
            patient = payload.fetch(:patient)
            default_class = constants.default_class_for(doctor.fetch(:profession_code))
            payer = build_payer

            {
              encounter_identifier: encounter[:identifier] || id_generator.call,
              episode_identifier: encounter[:episode_id] || id_generator.call,
              resource_id: encounter[:resource_id],
              status: encounter[:status] || constants::DEFAULT_STATUS,
              start_time: encounter.fetch(:start_time),
              end_time: encounter.fetch(:end_time),
              class_code: encounter[:class_code] || default_class.fetch(:code),
              class_name: encounter[:class_name] || default_class.fetch(:display),
              patient_pesel: patient.fetch(:pesel),
              patient_name: [patient[:first_name], patient[:last_name]].join(' '),
              doctor_name: doctor.fetch(:name),
              doctor_identifier_system: doctor_identifier_system(doctor),
              doctor_identifier_value: doctor_identifier_value(doctor),
              doctor_profession_number: constants.profession_number_for(doctor.fetch(:profession_code)),
              provider_identifier_system: subject_provider_system,
              provider_identifier_value: subject.fetch(:identification_code),
              location_identifier_system: subject_location_system,
              location_identifier_value: subject_location_value,
              encounter_identifier_system: "urn:oid:2.16.840.1.113883.3.4424.2.7.#{subject.fetch(:identification_code)}.15.1",
              episode_identifier_system: "urn:oid:#{subject.fetch(:oid)}.15.5",
              payer_identifier_system: payer.fetch(:identifier_system),
              payer_identifier_value: payer.fetch(:identifier_value)
            }
          end

          private

          attr_reader :payload, :subject, :constants, :id_generator

          def build_payer
            payer = payload[:payer]
            return payer unless payer.nil?

            { identifier_system: constants.patient_pesel_system, identifier_value: payload.dig(:patient, :pesel) }
          end

          def doctor_identifier_system(doctor)
            base = blank?(doctor[:npwz]) ? constants::PATIENT_PESEL_IDENTIFICATION_SYSTEM : constants::DOCTOR_NPWZ_IDENTIFICATION_SYSTEM
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
end
