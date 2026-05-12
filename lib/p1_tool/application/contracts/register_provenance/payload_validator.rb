# frozen_string_literal: true

module P1Tool
  module Application
    module Contracts
      module RegisterProvenance
        class PayloadValidator < BaseRegistrationPayloadValidator
          def initialize(constants: P1Tool::Application::Builders::Encounter::Constants)
            super
          end

          private

          def apply_business_rules(validation:, normalized:, details:)
            normalized_payload = normalized_payload(validation, normalized)
            super
            validate_recorded_at!(normalized_payload, details)
            validate_references!(normalized_payload, details)
          end

          def validate_recorded_at!(normalized, details)
            recorded_at = normalized.dig(:provenance, :recorded_at)
            return unless parse_iso8601(recorded_at).nil?

            append_error(details, :provenance, :recorded_at, 'must be a valid ISO8601 date time')
          end

          def validate_references!(normalized, details)
            references = normalized[:references]
            return unless references.is_a?(Array)

            unless references.any? { |reference| reference[:resource_type] == 'Patient' }
              append_error(details, :references, :base, 'must include Patient reference')
            end

            return if references.any? { |reference| reference[:resource_type] == 'Encounter' }

            append_error(details, :references, :base, 'must include Encounter reference')
          end

          def payload_schema = PayloadSchema

          def validation_error_message = 'Register provenance payload validation failed'

          def practice_xml_name = 'provenance'
        end
      end
    end
  end
end
