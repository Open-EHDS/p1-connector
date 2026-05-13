# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Resource
          class FetchXml
            def initialize(resource_type:, reference_id:, client:, version_id: nil)
              @resource_type = resource_type
              @reference_id = reference_id
              @version_id = version_id
              @client = client
            end

            def call
              response = client.get_resource_xml(resource_type:, reference_id:, version_id:)
              record_event(http_status: response[:status])

              {
                resource_type:,
                reference_id:,
                version_id:,
                xml: response[:body],
                content_type: response.dig(:headers, 'Content-Type') || response.dig(:headers, 'content-type'),
                response_status: response[:status]
              }.compact
            end

            private

            attr_reader :resource_type, :reference_id, :version_id, :client

            def record_event(http_status:)
              P1Tool::Adapters::ExecutionEvents.record(
                event_type: 'p1_resource_fetched',
                metadata: {
                  http_status:,
                  resource_type:,
                  reference_id:,
                  version_id:
                }.compact
              )
            end
          end
        end
      end
    end
  end
end
