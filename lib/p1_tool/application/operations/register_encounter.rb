# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class RegisterEncounter
        include Support::ResolvesP1Client

        def self.call(input, config: nil, p1_client: nil)
          new(input, config:, p1_client:).call
        end

        def initialize(input, config:, p1_client: nil)
          @input = input
          @config = config || raise(ArgumentError, 'config is required for register_encounter operation')
          @p1_client = p1_client
        end

        def call
          validated_payload = payload_validator.validate!(payload: input.fetch(:payload), subject: subject_config)
          encounter_data = build_encounter_data(validated_payload)
          patient_result = resolve_patient(validated_payload)
          submission_result = submit_encounter(encounter_data, patient_result, validated_payload)

          build_result(encounter_data, patient_result, submission_result)
        end

        private

        attr_reader :input, :config, :p1_client

        def build_result(encounter_data, patient_result, submission_result)
          {
            resource_type: 'Encounter',
            encounter_identifier: encounter_data[:encounter_identifier],
            episode_identifier: encounter_data[:episode_identifier],
            patient_reference_id: patient_result[:patient_reference_id],
            patient_resolution: patient_result,
            submission: submission_result
          }.compact
        end

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
          P1Tool::Application::Integrations::P1::Patient::FindOrCreate
        end

        def submission_class
          P1Tool::Application::Integrations::P1::Encounter::Submit
        end

        def build_encounter_data(validated_payload)
          data_builder.new(payload: validated_payload, subject: subject_config).call
        end

        def resolve_patient(validated_payload)
          patient_resolver_class.new(
            payload: validated_payload,
            subject: subject_config,
            client: resolved_p1_client(validated_payload)
          ).call
        end

        def build_xml(encounter_data, patient_result)
          xml_builder.new(
            encounter_data.merge(patient_reference_id: patient_result.fetch(:patient_reference_id))
          ).call
        end

        def submit_encounter(encounter_data, patient_result, validated_payload)
          submission_class.new(
            xml: build_xml(encounter_data, patient_result),
            encounter_data:,
            patient_result:,
            subject: subject_config,
            client: resolved_p1_client(validated_payload)
          ).call
        end
      end
    end
  end
end
