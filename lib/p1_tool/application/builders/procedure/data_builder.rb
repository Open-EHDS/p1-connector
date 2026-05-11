# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module Procedure
        class DataBuilder
          include P1Tool::Application::Builders::SharedDataBuilderSupport

          def initialize(payload:, subject:, constants: Constants, element_catalog: P1Tool::Application::Builders::P1ElementCatalog.new)
            @payload = payload
            @subject = subject
            @constants = constants
            @element_catalog = element_catalog
          end

          def call
            procedure = payload.fetch(:procedure)
            doctor = payload.fetch(:doctor)
            patient = payload.fetch(:patient)
            element = build_element(procedure[:element_code])

            {
              resource_id: procedure[:resource_id],
              status: procedure[:status] || constants::DEFAULT_STATUS,
              icd_9_code: procedure.fetch(:icd_9_code),
              icd_9_name: procedure.fetch(:icd_9_name),
              encounter_reference_id: payload.fetch(:encounter).fetch(:resource_id),
              start_time: procedure.fetch(:start_time),
              end_time: procedure.fetch(:end_time),
              patient_pesel: patient.fetch(:pesel),
              patient_name: patient_name(patient),
              doctor_name: doctor.fetch(:name),
              doctor_identifier_system: doctor_identifier_system(doctor),
              doctor_identifier_value: doctor_identifier_value(doctor),
              doctor_profession_number: constants.profession_number_for(doctor.fetch(:profession_code)),
              location_identifier_system: subject_location_system,
              location_identifier_value: subject_location_value,
              element_code: element&.fetch(:code, nil),
              element_system: element&.fetch(:system, nil),
              element_display: element&.fetch(:display, nil)
            }.compact
          end

          private

          attr_reader :payload, :subject, :constants, :element_catalog

          def build_element(element_code)
            return nil if blank?(element_code)

            element_catalog.fetch(element_code)
          end
        end
      end
    end
  end
end
