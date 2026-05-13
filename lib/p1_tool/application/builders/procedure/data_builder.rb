# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module Procedure
        class DataBuilder
          include P1Tool::Application::Builders::SharedDataBuilderSupport

          def initialize(payload:, subject:, constants: Constants, element_catalog: P1Tool::Application::ReferenceData::P1ElementCatalog.new)
            @payload = payload
            @subject = subject
            @constants = constants
            @element_catalog = element_catalog
          end

          def call
            procedure = payload.fetch(:procedure)
            element = build_element(procedure[:element_code])

            procedure_data(procedure)
              .merge(patient_data)
              .merge(doctor_data)
              .merge(location_data)
              .merge(element_data(element))
              .compact
          end

          private

          attr_reader :payload, :subject, :constants, :element_catalog

          def procedure_data(procedure)
            {
              resource_id: procedure[:resource_id],
              status: procedure[:status] || constants::DEFAULT_STATUS,
              icd_9_code: procedure.fetch(:icd_9_code),
              icd_9_name: procedure.fetch(:icd_9_name),
              encounter_reference_id: payload.fetch(:encounter).fetch(:resource_id),
              start_time: procedure.fetch(:start_time),
              end_time: procedure.fetch(:end_time)
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

          def location_data
            {
              location_identifier_system: subject_location_system,
              location_identifier_value: subject_location_value
            }
          end

          def element_data(element)
            {
              element_code: element&.fetch(:code, nil),
              element_system: element&.fetch(:system, nil),
              element_display: element&.fetch(:display, nil)
            }
          end

          def build_element(element_code)
            return nil if blank?(element_code)

            element_catalog.fetch(element_code)
          end
        end
      end
    end
  end
end
