# frozen_string_literal: true

module P1Tool
  module Application
    module Contracts
      module GetResource
        class PayloadValidator
          include P1Tool::Application::Contracts::ValidationHelpers

          SUPPORTED_RESOURCE_TYPES = %w[Patient Encounter Procedure Condition Provenance].freeze

          def initialize(constants: P1Tool::Application::Builders::Encounter::Constants)
            @constants = constants
          end

          def validate!(payload:)
            normalized = deep_symbolize(payload)
            details = {}

            validate_doctor!(normalized, details)
            validate_resource!(normalized, details)
            return normalized if details.empty?

            raise P1Tool::InputValidationError.new('Get resource payload validation failed', details: details)
          end

          private

          attr_reader :constants

          def validate_doctor!(normalized, details)
            doctor = normalized[:doctor]
            unless doctor.is_a?(Hash)
              append_error(details, :doctor, :base, 'must be provided')
              return
            end

            append_error(details, :doctor, :name, 'must be filled') if blank?(doctor[:name])
            append_error(details, :doctor, :profession_code, 'must be filled') if blank?(doctor[:profession_code])

            if blank?(doctor[:npwz]) && blank?(doctor[:pesel])
              append_error(details, :doctor, :base, 'must include npwz or pesel')
            end

            return if blank?(doctor[:profession_code])
            return if constants.supported_profession_codes.include?(doctor[:profession_code])

            append_error(details, :doctor, :profession_code, "must be one of: #{constants.supported_profession_codes.join(', ')}")
          end

          def validate_resource!(normalized, details)
            resource = normalized[:resource]
            unless resource.is_a?(Hash)
              append_error(details, :resource, :base, 'must be provided')
              return
            end

            append_error(details, :resource, :resource_type, 'must be filled') if blank?(resource[:resource_type])
            append_error(details, :resource, :resource_id, 'must be filled') if blank?(resource[:resource_id])

            return if blank?(resource[:resource_type])
            return if SUPPORTED_RESOURCE_TYPES.include?(resource[:resource_type])

            append_error(details, :resource, :resource_type, "must be one of: #{SUPPORTED_RESOURCE_TYPES.join(', ')}")
          end
        end
      end
    end
  end
end
