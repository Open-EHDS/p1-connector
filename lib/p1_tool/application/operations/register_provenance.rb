# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class RegisterProvenance
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
          signature = signature_generator_class.new(
            payload: validated_payload,
            config:,
            client: resolved_p1_client(validated_payload),
            signature_client:
          ).call
          provenance_data = data_builder.new(payload: validated_payload, subject: subject_config, signature:).call
          xml = xml_builder.new(provenance_data).call
          submission_result = submission_class.new(
            xml:,
            provenance_data:,
            client: resolved_p1_client(validated_payload)
          ).call

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
