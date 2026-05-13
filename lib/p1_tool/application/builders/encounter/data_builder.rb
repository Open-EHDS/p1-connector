# frozen_string_literal: true

require 'securerandom'

module P1Tool
  module Application
    module Builders
      module Encounter
        class DataBuilder
          include P1Tool::Application::Builders::SharedDataBuilderSupport

          def initialize(payload:, subject:, constants: Constants, id_generator: -> { SecureRandom.uuid })
            @payload = payload
            @subject = subject
            @constants = constants
            @id_generator = id_generator
          end

          def call
            encounter = payload.fetch(:encounter)
            encounter_class = constants.encounter_class_for(encounter.fetch(:class_code))

            encounter_data(encounter, encounter_class)
              .merge(patient_data)
              .merge(doctor_data)
              .merge(subject_data)
              .merge(identifier_systems)
              .merge(payer_data)
          end

          private

          attr_reader :payload, :subject, :constants, :id_generator

          def encounter_data(encounter, encounter_class)
            {
              encounter_identifier: encounter[:identifier] || id_generator.call,
              episode_identifier: encounter[:episode_id] || id_generator.call,
              resource_id: encounter[:resource_id],
              status: encounter[:status] || constants::DEFAULT_STATUS,
              start_time: encounter.fetch(:start_time),
              end_time: encounter.fetch(:end_time),
              class_code: encounter_class.fetch(:code),
              class_name: encounter_class.fetch(:display)
            }
          end

          def patient_data
            patient = payload.fetch(:patient)

            {
              patient_pesel: patient.fetch(:pesel),
              patient_name: patient_name(patient)
            }
          end

          def doctor_data
            doctor = payload.fetch(:doctor)

            {
              doctor_name: doctor.fetch(:name),
              doctor_identifier_system: doctor_identifier_system(doctor),
              doctor_identifier_value: doctor_identifier_value(doctor),
              doctor_profession_number: constants.resolve_medical_profession_code(doctor)
            }
          end

          def subject_data
            {
              provider_identifier_system: subject_provider_system,
              provider_identifier_value: subject.fetch(:identification_code),
              location_identifier_system: subject_location_system,
              location_identifier_value: subject_location_value
            }
          end

          def identifier_systems
            {
              encounter_identifier_system: encounter_identifier_system,
              episode_identifier_system: "urn:oid:#{subject.fetch(:oid)}.15.5"
            }
          end

          def payer_data
            payer = build_payer

            {
              payer_identifier_system: payer.fetch(:identifier_system),
              payer_identifier_value: payer.fetch(:identifier_value)
            }
          end

          def encounter_identifier_system
            "urn:oid:2.16.840.1.113883.3.4424.2.7.#{subject.fetch(:identification_code)}.15.1"
          end

          def build_payer
            payer = payload[:payer]
            return payer unless payer.nil?

            { identifier_system: constants.patient_pesel_system, identifier_value: payload.dig(:patient, :pesel) }
          end
        end
      end
    end
  end
end
