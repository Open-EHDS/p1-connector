# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class GetResource
        def self.call(input, config: nil, p1_client: nil)
          new(input, config:, p1_client:).call
        end

        def initialize(input, config:, p1_client: nil)
          @input = input
          @config = config || raise(ArgumentError, 'config is required for get_resource operation')
          @p1_client = p1_client
        end

        def call
          validated_payload = payload_validator.validate!(payload: input.fetch(:payload))
          resource_type, fetch_result = fetch_resource(validated_payload)

          {
            resource_type:,
            reference_id: fetch_result[:reference_id],
            version_id: fetch_result[:version_id],
            xml: fetch_result[:xml],
            content_type: fetch_result[:content_type],
            response_status: fetch_result[:response_status]
          }.compact
        end

        private

        attr_reader :input, :config, :p1_client

        def payload_validator
          @payload_validator ||= P1Tool::Application::Contracts::GetResource::PayloadValidator.new
        end

        def fetch_class
          P1Tool::Application::Integrations::P1::Resource::FetchXml
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

        def fetch_resource(validated_payload)
          resource_payload = validated_payload.fetch(:resource)
          resource_type = resource_payload.fetch(:resource_type)
          fetch_result = fetch_class.new(
            resource_type:,
            reference_id: resource_payload.fetch(:resource_id),
            version_id: resource_payload[:version_id],
            client: resolved_p1_client(validated_payload)
          ).call

          [resource_type, fetch_result]
        end
      end
    end
  end
end
