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

            class_presence = encounter_class_presence(encounter)
            return if encounter_class_complete?(class_presence)
            return if encounter_class_optional?(class_presence, normalized)

            return append_partial_encounter_class_errors(details) if encounter_class_partial?(class_presence)

            append_required_encounter_class_errors(details)
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

          def encounter_class_presence(encounter)
            {
              code: !blank?(encounter[:class_code]),
              name: !blank?(encounter[:class_name])
            }
          end

          def encounter_class_complete?(class_presence)
            class_presence[:code] && class_presence[:name]
          end

          def encounter_class_optional?(class_presence, normalized)
            !class_presence[:code] &&
              !class_presence[:name] &&
              !constants.default_class_for(normalized.dig(:doctor, :profession_code)).nil?
          end

          def encounter_class_partial?(class_presence)
            class_presence[:code] != class_presence[:name]
          end

          def append_partial_encounter_class_errors(details)
            append_error(details, :encounter, :class_code, 'must be provided together with class_name')
            append_error(details, :encounter, :class_name, 'must be provided together with class_code')
          end

          def append_required_encounter_class_errors(details)
            append_error(details, :encounter, :class_code, 'is required for this profession_code')
            append_error(details, :encounter, :class_name, 'is required for this profession_code')
          end

          def payload_schema = PayloadSchema

          def validation_error_message = 'Register encounter payload validation failed'

          def practice_xml_name = 'encounter'
        end
      end
    end
  end
end
