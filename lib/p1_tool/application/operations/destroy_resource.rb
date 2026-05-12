# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class DestroyResource
        include Support::ResolvesP1Client

        def self.call(input, config: nil, p1_client: nil)
          new(input, config:, p1_client:).call
        end

        def initialize(input, config:, p1_client: nil)
          @input = input
          @config = config || raise(ArgumentError, 'config is required for destroy_resource operation')
          @p1_client = p1_client
        end

        def call
          validated_payload = payload_validator.validate!(payload: input.fetch(:payload))
          destroy_resource(validated_payload)
        end

        private

        attr_reader :input, :config, :p1_client

        def payload_validator
          @payload_validator ||= P1Tool::Application::Contracts::DestroyResource::PayloadValidator.new
        end

        def destroy_class
          P1Tool::Application::Integrations::P1::Resource::Destroy
        end

        def destroy_resource(validated_payload)
          resource_payload = validated_payload.fetch(:resource)

          destroy_class.new(
            resource_type: resource_payload.fetch(:resource_type),
            reference_id: resource_payload.fetch(:resource_id),
            client: resolved_p1_client(validated_payload)
          ).call
        end
      end
    end
  end
end
