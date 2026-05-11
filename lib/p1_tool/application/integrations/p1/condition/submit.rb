# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Condition
          class Submit
            def initialize(xml:, condition_data:, patient_result:, client:)
              @xml = xml
              @condition_data = condition_data
              @patient_result = patient_result
              @client = client
            end

            def call
              reference_id = condition_data[:resource_id]

              response =
                if present?(reference_id)
                  client.update_resource(resource_type: 'Condition', reference_id:, xml:)
                else
                  client.create_resource(resource_type: 'Condition', xml:)
                end

              P1Tool::Runtime::CurrentExecution.record_event(
                event_type: 'p1_condition_submitted',
                metadata: {
                  http_status: response[:status],
                  submission_mode: present?(reference_id) ? 'update' : 'create',
                  reference_id: response[:reference_id],
                  version_id: response[:version_id]
                }.compact
              )

              {
                status: present?(reference_id) ? 'updated' : 'created',
                action: 'submit_condition_to_p1',
                submitted: true,
                reference_id: response[:reference_id],
                response_status: response[:status],
                version_id: response[:version_id]
              }.compact
            end

            private

            attr_reader :xml, :condition_data, :patient_result, :client

            def present?(value)
              !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
            end
          end
        end
      end
    end
  end
end
