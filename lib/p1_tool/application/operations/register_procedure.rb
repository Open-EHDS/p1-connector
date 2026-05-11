# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class RegisterProcedure
        def self.call(input, config: nil, p1_client: nil)
          new(input, config:, p1_client:).call
        end

        def initialize(input, config:, p1_client: nil)
          @input = input
          @config = config || raise(ArgumentError, 'config is required for register_procedure operation')
          @p1_client = p1_client
        end

        def call
          validated_payload = payload_validator.validate!(payload: input.fetch(:payload), subject: subject_config)
          procedure_data = data_builder.new(payload: validated_payload, subject: subject_config).call
          patient_result = patient_resolver_class.new(
            payload: validated_payload,
            subject: subject_config,
            client: resolved_p1_client(validated_payload)
          ).call
          xml = xml_builder.new(procedure_data.merge(patient_reference_id: patient_result.fetch(:patient_reference_id))).call
          submission_result = submission_class.new(
            xml:,
            procedure_data:,
            patient_result:,
            client: resolved_p1_client(validated_payload)
          ).call

          {
            resource_type: 'Procedure',
            encounter_reference_id: procedure_data[:encounter_reference_id],
            patient_reference_id: patient_result[:patient_reference_id],
            patient_resolution: patient_result,
            submission: submission_result
          }.compact
        end

        private

        attr_reader :input, :config, :p1_client

        def subject_config
          config.fetch(:subject)
        end

        def payload_validator
          @payload_validator ||= P1Tool::Application::Contracts::RegisterProcedure::PayloadValidator.new
        end

        def data_builder
          P1Tool::Application::Builders::Procedure::DataBuilder
        end

        def xml_builder
          P1Tool::Application::Builders::Procedure::XmlBuilder
        end

        def patient_resolver_class
          P1Tool::Application::Integrations::P1::Patient::FindOrCreate
        end

        def submission_class
          P1Tool::Application::Integrations::P1::Procedure::Submit
        end

        def resolved_p1_client(validated_payload)
          @resolved_p1_client ||= p1_client || build_p1_client(validated_payload)
        end

        def build_p1_client(validated_payload)
          P1Tool::Gateways::P1::ClientFactory.build(
            config:,
            doctor: validated_payload.fetch(:doctor)
          )
        end
      end
    end
  end
end
