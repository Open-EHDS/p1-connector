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
            doctor = payload.fetch(:doctor)
            patient = payload.fetch(:patient)
            encounter_class = constants.encounter_class_for(encounter.fetch(:class_code))
            payer = build_payer

            {
              encounter_identifier: encounter[:identifier] || id_generator.call,
              episode_identifier: encounter[:episode_id] || id_generator.call,
              resource_id: encounter[:resource_id],
              status: encounter[:status] || constants::DEFAULT_STATUS,
              start_time: encounter.fetch(:start_time),
              end_time: encounter.fetch(:end_time),
              class_code: encounter_class.fetch(:code),
              class_name: encounter_class.fetch(:display),
              patient_pesel: patient.fetch(:pesel),
              patient_name: patient_name(patient),
              doctor_name: doctor.fetch(:name),
              doctor_identifier_system: doctor_identifier_system(doctor),
              doctor_identifier_value: doctor_identifier_value(doctor),
              doctor_profession_number: constants.resolve_medical_profession_code(doctor),
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
        end
      end
    end
  end
end
