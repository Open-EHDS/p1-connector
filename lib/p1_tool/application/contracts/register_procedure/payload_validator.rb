# frozen_string_literal: true

require 'time'

module P1Tool
  module Application
    module Contracts
      module RegisterProcedure
        class PayloadValidator
          include P1Tool::Application::Contracts::ValidationHelpers

          def initialize(
            constants: P1Tool::Application::Builders::Procedure::Constants,
            element_catalog: P1Tool::Application::Builders::P1ElementCatalog.new
          )
            @constants = constants
            @element_catalog = element_catalog
          end

          def validate!(payload:, subject:)
            validate_subject!(subject)
            validation = PayloadSchema.call(payload)
            details = validation.errors.to_h.dup
            normalized = deep_symbolize(payload)
            apply_business_rules(validation:, normalized:, details:)
            return validation.to_h if validation.success? && details.empty?

            raise P1Tool::InputValidationError.new('Register procedure payload validation failed', details: details)
          end

          private

          attr_reader :constants, :element_catalog

          def apply_business_rules(validation:, normalized:, details:)
            return unless validation.success? || normalized.is_a?(Hash)

            normalized = validation.success? ? validation.to_h : normalized
            validate_doctor!(normalized, details)
            validate_period!(normalized, details)
            validate_element_code!(normalized, details)
          end

          def validate_subject!(subject)
            return unless subject.fetch(:is_practice)
            return unless blank?(subject[:medical_chamber])

            raise P1Tool::ConfigurationError, 'subject.medical_chamber is required for practice procedure XML'
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

          def validate_period!(normalized, details)
            procedure = normalized[:procedure]
            return unless procedure.is_a?(Hash)

            start_time = parse_iso8601(procedure[:start_time])
            end_time = parse_iso8601(procedure[:end_time])
            append_error(details, :procedure, :start_time, 'must be a valid ISO8601 date time') if start_time.nil?
            append_error(details, :procedure, :end_time, 'must be a valid ISO8601 date time') if end_time.nil?
            return if start_time.nil? || end_time.nil? || end_time >= start_time

            append_error(details, :procedure, :end_time, 'must be greater than or equal to start_time')
          end

          def validate_element_code!(normalized, details)
            element_code = normalized.dig(:procedure, :element_code)
            return if blank?(element_code)
            return if element_catalog.fetch(element_code)

            append_error(details, :procedure, :element_code, 'is not present in P1 procedure element catalog')
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
