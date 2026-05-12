# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Provenance
          class Submit
            def initialize(xml:, provenance_data:, client:)
              @xml = xml
              @provenance_data = provenance_data
              @client = client
            end

            def call
              reference_id = provenance_data[:resource_id]

              response =
                if present?(reference_id)
                  client.update_resource(resource_type: 'Provenance', reference_id:, xml:)
                else
                  client.create_resource(resource_type: 'Provenance', xml:)
                end

              P1Tool::Adapters::ExecutionEvents.record(
                event_type: 'p1_provenance_submitted',
                metadata: {
                  http_status: response[:status],
                  submission_mode: present?(reference_id) ? 'update' : 'create',
                  reference_id: response[:reference_id],
                  version_id: response[:version_id]
                }.compact
              )

              {
                status: present?(reference_id) ? 'updated' : 'created',
                action: 'submit_provenance_to_p1',
                submitted: true,
                reference_id: response[:reference_id],
                response_status: response[:status],
                version_id: response[:version_id]
              }.compact
            end

            private

            attr_reader :xml, :provenance_data, :client

            def present?(value)
              !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
            end
          end
        end
      end
    end
  end
end
