# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class RegisterEncounter
        def self.call(input, config: nil)
          new(input, config:).call
        end

        def initialize(input, config:)
          @input = input
          @config = config || raise(ArgumentError, 'config is required for register_encounter operation')
        end

        def call
          validated_payload = payload_validator.validate!(payload: input.fetch(:payload), subject: subject_config)
          encounter_data = data_builder.new(payload: validated_payload, subject: subject_config).call
          patient_result = patient_resolver_class.new(payload: validated_payload, subject: subject_config).call
          xml = xml_builder.new(encounter_data.merge(patient_reference_id: patient_result.fetch(:patient_reference_id))).call
          submission_result = submission_class.new(xml:, encounter_data:, patient_result:, subject: subject_config).call

          {
            resource_type: 'Encounter',
            encounter_identifier: encounter_data[:encounter_identifier],
            episode_identifier: encounter_data[:episode_identifier],
            patient_reference_id: patient_result[:patient_reference_id],
            patient_resolution: patient_result,
            submission: submission_result
          }.compact
        end

        private

        attr_reader :input, :config

        def subject_config
          config.fetch(:subject)
        end

        def payload_validator
          @payload_validator ||= P1Tool::Application::Contracts::RegisterEncounter::PayloadValidator.new
        end

        def data_builder
          P1Tool::Application::Builders::Encounter::DataBuilder
        end

        def xml_builder
          P1Tool::Application::Builders::Encounter::XmlBuilder
        end

        def patient_resolver_class
          P1Tool::Application::Integrations::P1::Patient::FindOrCreateStub
        end

        def submission_class
          P1Tool::Application::Integrations::P1::Encounter::SubmitStub
        end
      end
    end
  end
end
