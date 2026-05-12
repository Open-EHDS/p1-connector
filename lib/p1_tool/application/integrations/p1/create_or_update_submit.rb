# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        class CreateOrUpdateSubmit
          def initialize(xml:, resource_data:, client:)
            @xml = xml
            @resource_data = resource_data
            @client = client
          end

          def call
            reference_id = resource_data[:resource_id]
            response = persist_resource(reference_id)
            record_submission(reference_id, response)
            build_result(reference_id, response)
          end

          private

          attr_reader :xml, :resource_data, :client

          def resource_type = self.class::RESOURCE_TYPE

          def submission_event_type = self.class::SUBMISSION_EVENT_TYPE

          def submission_action = self.class::SUBMISSION_ACTION

          def persist_resource(reference_id)
            if present?(reference_id)
              client.update_resource(resource_type:, reference_id:, xml:)
            else
              client.create_resource(resource_type:, xml:)
            end
          end

          def record_submission(reference_id, response)
            P1Tool::Adapters::ExecutionEvents.record(
              event_type: submission_event_type,
              metadata: submission_metadata(reference_id, response)
            )
          end

          def submission_metadata(reference_id, response)
            {
              http_status: response[:status],
              submission_mode: submission_mode(reference_id),
              reference_id: response[:reference_id],
              version_id: response[:version_id]
            }.compact
          end

          def build_result(reference_id, response)
            {
              status: submission_status(reference_id),
              action: submission_action,
              submitted: true,
              reference_id: response[:reference_id],
              response_status: response[:status],
              version_id: response[:version_id]
            }.compact
          end

          def submission_mode(reference_id)
            present?(reference_id) ? 'update' : 'create'
          end

          def submission_status(reference_id)
            present?(reference_id) ? 'updated' : 'created'
          end

          def present?(value)
            !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
          end
        end
      end
    end
  end
end
