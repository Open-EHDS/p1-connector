# frozen_string_literal: true

require 'time'

module P1Tool
  module Application
    module Contracts
      class BaseRegistrationPayloadValidator
        include P1Tool::Application::Contracts::ValidationHelpers

        def initialize(constants:)
          @constants = constants
        end

        def validate!(payload:, subject:)
          validate_subject!(subject)
          validation = payload_schema.call(payload)
          details = validation.errors.to_h.dup
          normalized = normalize_payload(payload)
          apply_business_rules(validation:, normalized:, details:)
          return validation.to_h if validation.success? && details.empty?

          raise P1Tool::InputValidationError.new(validation_error_message, details: details)
        end

        private

        attr_reader :constants

        def apply_business_rules(validation:, normalized:, details:)
          return unless validation.success? || normalized.is_a?(Hash)

          validate_doctor!(normalized_payload(validation, normalized), details)
        end

        def validate_subject!(subject)
          return unless subject.fetch(:is_practice)
          return unless blank?(subject[:medical_chamber])

          raise P1Tool::ConfigurationError, "subject.medical_chamber is required for practice #{practice_xml_name} XML"
        end

        def validate_doctor!(normalized, details)
          doctor = normalized[:doctor]
          return unless doctor.is_a?(Hash)

          if blank?(doctor[:npwz]) && blank?(doctor[:pesel])
            append_error(details, :doctor, :base, 'must include npwz or pesel')
          end

          return if constants.supported_profession_codes.include?(doctor[:profession_code])

          append_error(
            details,
            :doctor,
            :profession_code,
            "must be one of: #{constants.supported_profession_codes.join(', ')}"
          )
        end

        def validate_period!(normalized, details, section:)
          section_payload = normalized[section]
          return unless section_payload.is_a?(Hash)

          start_time = parse_iso8601(section_payload[:start_time])
          end_time = parse_iso8601(section_payload[:end_time])
          append_error(details, section, :start_time, 'must be a valid ISO8601 date time') if start_time.nil?
          append_error(details, section, :end_time, 'must be a valid ISO8601 date time') if end_time.nil?
          return if start_time.nil? || end_time.nil? || end_time >= start_time

          append_error(details, section, :end_time, 'must be greater than or equal to start_time')
        end

        def validate_element_code!(normalized, details, section:, element_catalog:)
          element_code = normalized.dig(section, :element_code)
          return if blank?(element_code)
          return if element_catalog.fetch(element_code)

          append_error(details, section, :element_code, 'is not present in P1 element catalog')
        end

        def parse_iso8601(value)
          Time.iso8601(value)
        rescue ArgumentError
          nil
        end

        def normalize_payload(payload)
          deep_symbolize(payload)
        end

        def normalized_payload(validation, normalized)
          validation.success? ? validation.to_h : normalized
        end

        def payload_schema
          raise NotImplementedError, "#{self.class} must implement ##{__method__}"
        end

        def validation_error_message
          raise NotImplementedError, "#{self.class} must implement ##{__method__}"
        end

        def practice_xml_name
          raise NotImplementedError, "#{self.class} must implement ##{__method__}"
        end
      end
    end
  end
end
