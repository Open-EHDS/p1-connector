# frozen_string_literal: true

module P1Tool
  module Application
    module Contracts
      module ValidationHelpers
        private

        def deep_symbolize(value)
          case value
          when Hash then value.each_with_object({}) do |(key, nested), result|
            result[key.to_sym] = deep_symbolize(nested)
          end
          when Array then value.map { |item| deep_symbolize(item) }
          else value
          end
        end

        def append_error(details, group, field, message)
          details[group] ||= {}
          details[group][field] ||= []
          details[group][field] << message
        end

        def validate_doctor_required_fields!(doctor, details)
          append_error(details, :doctor, :name, 'must be filled') if blank?(doctor[:name])
          append_error(details, :doctor, :profession_code, 'must be filled') if blank?(doctor[:profession_code])
        end

        def validate_doctor_identity!(doctor, details)
          return unless blank?(doctor[:npwz]) && blank?(doctor[:pesel])

          append_error(details, :doctor, :base, 'must include npwz or pesel')
        end

        def validate_doctor_profession!(doctor, details, supported_profession_codes)
          return if blank?(doctor[:profession_code])
          return if supported_profession_codes.include?(doctor[:profession_code])

          append_error(
            details,
            :doctor,
            :profession_code,
            "must be one of: #{supported_profession_codes.join(', ')}"
          )
        end

        def blank?(value)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end
    end
  end
end
