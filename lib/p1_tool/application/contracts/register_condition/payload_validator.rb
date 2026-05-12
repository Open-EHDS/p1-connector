# frozen_string_literal: true

module P1Tool
  module Application
    module Contracts
      module RegisterCondition
        class PayloadValidator < BaseRegistrationPayloadValidator
          def initialize(
            constants: P1Tool::Application::Builders::Condition::Constants,
            element_catalog: P1Tool::Application::ReferenceData::P1ElementCatalog.new
          )
            super(constants:)
            @element_catalog = element_catalog
          end

          private

          attr_reader :element_catalog

          def apply_business_rules(validation:, normalized:, details:)
            normalized_payload = normalized_payload(validation, normalized)
            super
            validate_recorded_date!(normalized_payload, details)
            validate_category!(normalized_payload, details)
            validate_element_code!(normalized_payload, details, section: :condition, element_catalog:)
          end

          def validate_recorded_date!(normalized, details)
            recorded_date = normalized.dig(:condition, :recorded_date)
            return unless parse_iso8601(recorded_date).nil?

            append_error(details, :condition, :recorded_date, 'must be a valid ISO8601 date time')
          end

          def validate_category!(normalized, details)
            category = normalized.dig(:condition, :category)
            return if blank?(category)
            return if constants.supported_condition_category_codes.include?(category)

            append_error(
              details,
              :condition,
              :category,
              "must be one of: #{constants.supported_condition_category_codes.join(', ')}"
            )
          end

          def payload_schema = PayloadSchema

          def validation_error_message = 'Register condition payload validation failed'

          def practice_xml_name = 'condition'
        end
      end
    end
  end
end
