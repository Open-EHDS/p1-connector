# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module Condition
        class DataBuilder
          include P1Tool::Application::Builders::SharedDataBuilderSupport

          def initialize(payload:, subject:, constants: Constants, element_catalog: P1Tool::Application::ReferenceData::P1ElementCatalog.new)
            @payload = payload
            @subject = subject
            @constants = constants
            @element_catalog = element_catalog
          end

          def call
            condition = payload.fetch(:condition)
            element = build_element(condition[:element_code])
            category_code = condition[:category] || constants::DEFAULT_CONDITION_CATEGORY_CODE

            condition_data(condition, category_code)
              .merge(patient_data)
              .merge(doctor_data)
              .merge(location_data)
              .merge(element_data(element))
              .compact
          end

          private

          attr_reader :payload, :subject, :constants, :element_catalog

          def condition_data(condition, category_code)
            {
              resource_id: condition[:resource_id],
              icd_10_code: condition.fetch(:icd_10_code),
              icd_10_name: condition.fetch(:icd_10_name),
              category_code:,
              category_display: constants.condition_category_display_for(category_code),
              encounter_reference_id: payload.fetch(:encounter).fetch(:resource_id),
              recorded_date: condition.fetch(:recorded_date)
            }
          end

          def patient_data
            {
              patient_pesel: payload.fetch(:patient).fetch(:pesel)
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
