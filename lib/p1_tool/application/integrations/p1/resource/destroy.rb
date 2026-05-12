# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Resource
          class Destroy
            def initialize(resource_type:, reference_id:, client:)
              @resource_type = resource_type
              @reference_id = reference_id
              @client = client
            end

            def call
              response = client.destroy_resource(resource_type:, reference_id:)
              record_event(http_status: response[:status])

              {
                resource_type:,
                reference_id:,
                response_status: response[:status]
              }
            end

            private

            attr_reader :resource_type, :reference_id, :client

            def record_event(http_status:)
              P1Tool::Adapters::ExecutionEvents.record(
                event_type: 'p1_resource_destroyed',
                metadata: {
                  http_status:,
                  resource_type:,
                  reference_id:
                }
              )
            end
          end
        end
      end
    end
  end
end
