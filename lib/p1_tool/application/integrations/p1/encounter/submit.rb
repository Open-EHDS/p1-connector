# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Encounter
          class Submit
            def initialize(xml:, encounter_data:, patient_result:, subject:, client:)
              @xml = xml
              @encounter_data = encounter_data
              @patient_result = patient_result
              @subject = subject
              @client = client
            end

            def call
              reference_id = encounter_data[:resource_id]

              response =
                if present?(reference_id)
                  client.update_resource(resource_type: 'Encounter', reference_id:, xml:)
                else
                  client.create_resource(resource_type: 'Encounter', xml:)
                end

              P1Tool::Adapters::ExecutionEvents.record(
                event_type: 'p1_encounter_submitted',
                metadata: {
                  http_status: response[:status],
                  submission_mode: present?(reference_id) ? 'update' : 'create',
                  reference_id: response[:reference_id],
                  version_id: response[:version_id]
                }.compact
              )

              {
                status: present?(reference_id) ? 'updated' : 'created',
                action: 'submit_encounter_to_p1',
                submitted: true,
                reference_id: response[:reference_id],
                response_status: response[:status],
                version_id: response[:version_id]
              }.compact
            end

            private

            attr_reader :xml, :encounter_data, :patient_result, :subject, :client

            def present?(value)
              !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
            end

          end
        end
      end
    end
  end
end
