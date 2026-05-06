# frozen_string_literal: true

module P1Tool
  module Application
    module Integrations
      module P1
        module Patient
          class FindOrCreate
            def initialize(payload:, subject:, client:, xml_builder: Builders::Patient::XmlBuilder)
              @payload = payload
              @subject = subject
              @client = client
              @xml_builder = xml_builder
            end

            def call
              found_patient_id = find_existing_patient_id
              return found_result(found_patient_id) if found_patient_id

              response = client.create_resource(resource_type: 'Patient', xml: xml_builder.new(payload:).call)
              P1Tool::Runtime::CurrentExecution.record_event(
                event_type: 'p1_patient_created',
                metadata: {
                  http_status: response.fetch(:status),
                  patient_reference_id: response.fetch(:reference_id)
                }
              )

              {
                status: 'created',
                action: 'find_or_create_patient',
                patient_reference_id: response.fetch(:reference_id),
                response_status: response.fetch(:status)
              }
            end

            private

            attr_reader :payload, :subject, :client, :xml_builder

            def find_existing_patient_id
              response = client.find_patient(payload:)
              bundle = response[:body]
              patient_id =
                if bundle.is_a?(Hash) && bundle['total'].to_i.positive?
                  bundle.dig('entry', 0, 'resource', 'id')
                end

              P1Tool::Runtime::CurrentExecution.record_event(
                event_type: 'p1_patient_lookup_finished',
                metadata: {
                  http_status: response[:status],
                  found: !patient_id.nil?,
                  patient_reference_id: patient_id
                }.compact
              )
              return if patient_id.nil?

              patient_id
            end

            def found_result(patient_id)
              {
                status: 'found',
                action: 'find_or_create_patient',
                patient_reference_id: patient_id
              }
            end

          end
        end
      end
    end
  end
end
