# frozen_string_literal: true

require 'time'

module P1Tool
  module Application
    module Contracts
      module RegisterProvenance
        class PayloadValidator
          include P1Tool::Application::Contracts::ValidationHelpers

          def initialize(constants: P1Tool::Application::Builders::Encounter::Constants)
            @constants = constants
          end

          def validate!(payload:, subject:)
            validate_subject!(subject)
            validation = PayloadSchema.call(payload)
            details = validation.errors.to_h.dup
            normalized = deep_symbolize(payload)
            apply_business_rules(validation:, normalized:, details:)
            return validation.to_h if validation.success? && details.empty?

            raise P1Tool::InputValidationError.new('Register provenance payload validation failed', details: details)
          end

          private

          attr_reader :constants

          def apply_business_rules(validation:, normalized:, details:)
            return unless validation.success? || normalized.is_a?(Hash)

            normalized = validation.success? ? validation.to_h : normalized
            validate_doctor!(normalized, details)
            validate_recorded_at!(normalized, details)
            validate_references!(normalized, details)
          end

          def validate_subject!(subject)
            return unless subject.fetch(:is_practice)
            return unless blank?(subject[:medical_chamber])

            raise P1Tool::ConfigurationError, 'subject.medical_chamber is required for practice provenance XML'
          end

          def validate_doctor!(normalized, details)
            doctor = normalized[:doctor]
            return unless doctor.is_a?(Hash)

            if blank?(doctor[:npwz]) && blank?(doctor[:pesel])
              details[:doctor] ||= {}
              details[:doctor][:base] ||= []
              details[:doctor][:base] << 'must include npwz or pesel'
            end

            return if constants.supported_profession_codes.include?(doctor[:profession_code])

            details[:doctor] ||= {}
            details[:doctor][:profession_code] ||= []
            details[:doctor][:profession_code] << "must be one of: #{constants.supported_profession_codes.join(', ')}"
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

            unless references.any? { |reference| reference[:resource_type] == 'Encounter' }
              append_error(details, :references, :base, 'must include Encounter reference')
            end
          end

          def parse_iso8601(value)
            Time.iso8601(value)
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end
