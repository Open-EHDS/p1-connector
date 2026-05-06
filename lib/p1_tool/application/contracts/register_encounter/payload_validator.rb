# frozen_string_literal: true

require 'time'

module P1Tool
  module Application
    module Contracts
      module RegisterEncounter
        class PayloadValidator
          include ValidationHelpers

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
            raise P1Tool::InputValidationError.new('Register encounter payload validation failed', details: details)
          end

          private

          attr_reader :constants

          def apply_business_rules(validation:, normalized:, details:)
            return unless validation.success? || normalized.is_a?(Hash)

            normalized = validation.success? ? validation.to_h : normalized
            validate_doctor!(normalized, details)
            validate_encounter_period!(normalized, details)
            validate_encounter_class!(normalized, details)
            validate_payer!(normalized, details)
          end

          def validate_subject!(subject)
            return unless subject.fetch(:is_practice)
            return unless blank?(subject[:medical_chamber])

            raise P1Tool::ConfigurationError, 'subject.medical_chamber is required for practice encounter XML'
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

          def validate_encounter_period!(normalized, details)
            encounter = normalized[:encounter]
            return unless encounter.is_a?(Hash)

            start_time = parse_iso8601(encounter[:start_time])
            end_time = parse_iso8601(encounter[:end_time])
            append_error(details, :encounter, :start_time, 'must be a valid ISO8601 date time') if start_time.nil?
            append_error(details, :encounter, :end_time, 'must be a valid ISO8601 date time') if end_time.nil?
            return if start_time.nil? || end_time.nil? || end_time >= start_time

            append_error(details, :encounter, :end_time, 'must be greater than or equal to start_time')
          end

          def validate_encounter_class!(normalized, details)
            encounter = normalized[:encounter]
            return unless encounter.is_a?(Hash)

            has_code = !blank?(encounter[:class_code])
            has_name = !blank?(encounter[:class_name])
            return if has_code && has_name
            return if !has_code && !has_name && !constants.default_class_for(normalized.dig(:doctor, :profession_code)).nil?

            if has_code != has_name
              append_error(details, :encounter, :class_code, 'must be provided together with class_name')
              append_error(details, :encounter, :class_name, 'must be provided together with class_code')
              return
            end

            append_error(details, :encounter, :class_code, 'is required for this profession_code')
            append_error(details, :encounter, :class_name, 'is required for this profession_code')
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
