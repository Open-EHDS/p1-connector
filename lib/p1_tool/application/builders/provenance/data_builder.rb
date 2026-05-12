# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module Provenance
        class DataBuilder
          include P1Tool::Application::Builders::SharedDataBuilderSupport

          def initialize(payload:, subject:, signature:, constants: Constants)
            @payload = payload
            @subject = subject
            @signature = signature
            @constants = constants
          end

          def call
            provenance = payload.fetch(:provenance)

            {
              resource_id: provenance[:resource_id],
              recorded_at: provenance.fetch(:recorded_at),
              targets: payload.fetch(:references).map do |reference|
                {
                  resource_type: reference.fetch(:resource_type),
                  reference_id: reference.fetch(:reference_id),
                  version_id: reference.fetch(:version_id)
                }
              end,
              provider_identifier_system: subject_provider_system,
              provider_identifier_value: subject.fetch(:identification_code),
              signature: signature
            }.compact
          end

          private

          attr_reader :payload, :subject, :signature, :constants
        end
      end
    end
  end
end
