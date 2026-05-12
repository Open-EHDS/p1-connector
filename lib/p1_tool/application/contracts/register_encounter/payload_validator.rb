# frozen_string_literal: true

module P1Tool
  module Application
    module Contracts
      module RegisterEncounter
        class PayloadValidator < BaseRegistrationPayloadValidator
          def initialize(constants: P1Tool::Application::Builders::Encounter::Constants)
            super
          end

          private

          def apply_business_rules(validation:, normalized:, details:)
            normalized_payload = normalized_payload(validation, normalized)
            super
            validate_period!(normalized_payload, details, section: :encounter)
            validate_encounter_class!(normalized_payload, details)
            validate_payer!(normalized_payload, details)
          end

          def validate_encounter_class!(normalized, details)
            encounter = normalized[:encounter]
            return unless encounter.is_a?(Hash)

            class_code = encounter[:class_code]
            return if blank?(class_code)

            unless constants.supported_class_codes.include?(class_code)
              append_error(details, :encounter, :class_code, 'is not present in PLMedicalEventClass dictionary')
              return
            end

            class_name = encounter[:class_name]
            return if blank?(class_name)

            expected_display = constants.encounter_class_for(class_code).fetch(:display)
            return if class_name == expected_display

            append_error(details, :encounter, :class_name, "must match class_code display: #{expected_display}")
          end

          def validate_payer!(normalized, details)
            payer = normalized[:payer]
            return if payer.nil?

            identifier_system_present = !blank?(payer[:identifier_system])
            identifier_value_present = !blank?(payer[:identifier_value])
            return if identifier_system_present == identifier_value_present

            append_error(details, :payer, :identifier_system, 'must be provided together with identifier_value')
            append_error(details, :payer, :identifier_value, 'must be provided together with identifier_system')
          end

          def payload_schema = PayloadSchema

          def medical_profession_code_required? = true

          def validation_error_message = 'Register encounter payload validation failed'

          def practice_xml_name = 'encounter'
        end
      end
    end
  end
end
