# frozen_string_literal: true

require 'jwt'
require 'securerandom'

module P1Tool
  module Gateways
    module P1
      class TokenBuilder
        def initialize(subject:, doctor:, clock: -> { Time.now.utc }, uuid_generator: -> { SecureRandom.uuid })
          @subject = subject
          @doctor = doctor
          @clock = clock
          @uuid_generator = uuid_generator
        end

        def payload
          now = clock.call

          {
            'iss' => subject_token_oid,
            'sub' => subject_token_oid,
            'aud' => Constants::TOKEN_AUDIENCE,
            'jti' => uuid_generator.call,
            'exp' => now.to_i + 300,
            'user_id' => doctor_user_identifier,
            'user_role' => doctor.fetch(:profession_code),
            'child_organization' => child_organization
          }.compact
        end

        def encode(wss_bundle)
          JWT.encode(payload, wss_bundle.key, 'RS256', { typ: 'JWT' })
        end

        private

        attr_reader :subject, :doctor, :clock, :uuid_generator

        def subject_token_oid
          return "#{Constants::PRACTICE_SYSTEM_PREFIX}#{subject.fetch(:medical_chamber)}:#{subject.fetch(:identification_code)}" if subject.fetch(:is_practice)

          "#{Constants::ENTITY_SYSTEM}:#{subject.fetch(:identification_code)}"
        end

        def doctor_user_identifier
          "#{doctor_identifier_system}:#{doctor_identifier_value}"
        end

        def doctor_identifier_system
          return Constants::DOCTOR_NPWZ_SYSTEM if present?(doctor[:npwz])

          Constants::PESEL_SYSTEM.delete_prefix('urn:oid:')
        end

        def doctor_identifier_value
          doctor[:npwz] || doctor[:pesel]
        end

        def child_organization
          return if subject.fetch(:is_practice)

          "#{subject.fetch(:oid)}:#{subject_location_value}"
        end

        def subject_location_value
          department = subject[:department_code_vii]
          department = subject[:department_code_v] unless present?(department)
          "#{subject.fetch(:identification_code)}-#{department}"
        end

        def present?(value)
          !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
        end
      end
    end
  end
end
