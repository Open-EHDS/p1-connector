# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class RegisterProvenance
        include Support::ResolvesP1Client

        def self.call(input, config: nil, p1_client: nil, signature_client: nil)
          new(input, config:, p1_client:, signature_client:).call
        end

        def initialize(input, config:, p1_client: nil, signature_client: nil)
          @input = input
          @config = config || raise(ArgumentError, 'config is required for register_provenance operation')
          @p1_client = p1_client
          @signature_client = signature_client
        end

        def call
          validated_payload = payload_validator.validate!(payload: input.fetch(:payload), subject: subject_config)
          signature = generate_signature(validated_payload)
          provenance_data = build_provenance_data(validated_payload, signature)
          submission_result = submit_provenance(provenance_data, validated_payload)

          {
            resource_type: 'Provenance',
            targets: provenance_data[:targets],
            submission: submission_result
          }.compact
        end

        private

        attr_reader :input, :config, :p1_client, :signature_client

        def subject_config
          config.fetch(:subject)
        end

        def payload_validator
          @payload_validator ||= P1Tool::Application::Contracts::RegisterProvenance::PayloadValidator.new
        end

        def data_builder
          P1Tool::Application::Builders::Provenance::DataBuilder
        end

        def xml_builder
          P1Tool::Application::Builders::Provenance::XmlBuilder
        end

        def signature_generator_class
          P1Tool::Application::Integrations::SignatureService::GenerateSignature
        end

        def submission_class
          P1Tool::Application::Integrations::P1::Provenance::Submit
        end

        def generate_signature(validated_payload)
          signature_generator_class.new(
            payload: validated_payload,
            config:,
            client: resolved_p1_client(validated_payload),
            signature_client:
          ).call
        end

        def build_provenance_data(validated_payload, signature)
          data_builder.new(payload: validated_payload, subject: subject_config, signature:).call
        end

        def submit_provenance(provenance_data, validated_payload)
          submission_class.new(
            xml: xml_builder.new(provenance_data).call,
            provenance_data:,
            client: resolved_p1_client(validated_payload)
          ).call
        end
      end
    end
  end
end
