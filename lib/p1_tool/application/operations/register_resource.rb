# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class RegisterResource
        def self.call(input, config: nil, p1_client: nil)
          new(input, config:, p1_client:).call
        end

        def initialize(input, config:, p1_client: nil)
          @input = input
          @config = config || raise(ArgumentError, "config is required for #{operation_kind} operation")
          @p1_client = p1_client
        end

        def call
          validated_payload = payload_validator.validate!(payload: input.fetch(:payload), subject: subject_config)
          resource_data = build_resource_data(validated_payload)
          patient_result = resolve_patient(validated_payload)
          xml = build_xml(resource_data, patient_result)
          submission_result = submit_resource(xml, resource_data, validated_payload)

          build_result(resource_data, patient_result, submission_result)
        end

        private

        attr_reader :input, :config, :p1_client

        def subject_config
          config.fetch(:subject)
        end

        def patient_resolver_class
          P1Tool::Application::Integrations::P1::Patient::FindOrCreate
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

        def build_resource_data(validated_payload)
          data_builder.new(payload: validated_payload, subject: subject_config).call
        end

        def resolve_patient(validated_payload)
          patient_resolver_class.new(
            payload: validated_payload,
            subject: subject_config,
            client: resolved_p1_client(validated_payload)
          ).call
        end

        def build_xml(resource_data, patient_result)
          payload = resource_data.merge(patient_reference_id: patient_result.fetch(:patient_reference_id))
          xml_builder.new(payload).call
        end

        def submit_resource(xml, resource_data, validated_payload)
          submission_class.new(
            xml:,
            resource_data:,
            client: resolved_p1_client(validated_payload)
          ).call
        end

        def build_result(resource_data, patient_result, submission_result)
          {
            resource_type: resource_type,
            encounter_reference_id: resource_data[:encounter_reference_id],
            patient_reference_id: patient_result[:patient_reference_id],
            patient_resolution: patient_result,
            submission: submission_result
          }.compact
        end

        def operation_kind
          raise NotImplementedError, "#{self.class} must implement ##{__method__}"
        end

        def resource_type
          raise NotImplementedError, "#{self.class} must implement ##{__method__}"
        end

        def payload_validator
          raise NotImplementedError, "#{self.class} must implement ##{__method__}"
        end

        def data_builder
          raise NotImplementedError, "#{self.class} must implement ##{__method__}"
        end

        def xml_builder
          raise NotImplementedError, "#{self.class} must implement ##{__method__}"
        end

        def submission_class
          raise NotImplementedError, "#{self.class} must implement ##{__method__}"
        end
      end
    end
  end
end
