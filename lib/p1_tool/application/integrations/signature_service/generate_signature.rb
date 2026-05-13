# frozen_string_literal: true

require 'base64'

module P1Tool
  module Application
    module Integrations
      module SignatureService
        class GenerateSignature
          def initialize(payload:, config:, client:, signature_client: nil)
            @payload = payload
            @config = config
            @client = client
            @signature_client = signature_client || build_signature_client
          end

          def call
            fetched_documents = fetch_signature_documents
            signature_response = signature_client.generate_signature(
              documents: build_signature_documents(fetched_documents)
            )

            P1Tool::Adapters::ExecutionEvents.record(
              event_type: 'signature_service_signature_generated',
              metadata: {
                reference_count: fetched_documents.size,
                fetched_document_count: fetched_documents.size,
                fetched_resource_types: fetched_documents.map { |document_entry| document_entry[:resource_type] },
                signature_service_url: config.dig(:signature_service, :url)
              }
            )

            signature_response['documentBase64'] || Base64.strict_encode64(signature_response.fetch('document'))
          end

          private

          attr_reader :payload, :config, :client, :signature_client

          def build_signature_client
            P1Tool::Gateways::SignatureService::Client.new(base_url: config.dig(:signature_service, :url))
          end

          def build_signature_documents(fetched_documents)
            fetched_documents.map do |document_entry|
              {
                uri: document_entry.fetch(:uri),
                mimeType: document_entry.fetch(:mime_type),
                content: document_entry.fetch(:content)
              }
            end
          end

          def reference_urls
            base_url = P1Tool::Gateways::P1::Constants.environment!(config.dig(:p1, :environment)).fetch(:base_url)

            payload.fetch(:references).map do |reference|
              reference_url(base_url, reference)
            end
          end

          def fetch_signature_documents
            payload.fetch(:references).zip(reference_urls).map do |reference, uri|
              build_document_entry(fetch_resource(reference), uri)
            end
          end

          def fetch_resource(reference)
            P1Tool::Application::Integrations::P1::Resource::FetchXml.new(
              resource_type: reference.fetch(:resource_type),
              reference_id: reference.fetch(:reference_id),
              version_id: reference.fetch(:version_id),
              client:
            ).call
          end

          def build_document_entry(fetched_resource, uri)
            {
              resource_type: fetched_resource.fetch(:resource_type),
              reference_id: fetched_resource.fetch(:reference_id),
              version_id: fetched_resource[:version_id],
              uri:,
              mime_type: normalize_mime_type(fetched_resource[:content_type]),
              content: fetched_resource.fetch(:xml)
            }.compact
          end

          def reference_url(base_url, reference)
            [
              base_url,
              'fhir',
              reference.fetch(:resource_type),
              reference.fetch(:reference_id),
              '_history',
              reference.fetch(:version_id)
            ].join('/')
          end

          def normalize_mime_type(content_type)
            mime_type = content_type.to_s.split(';').first.to_s.strip
            return 'application/fhir+xml' if mime_type.empty?

            mime_type
          end
        end
      end
    end
  end
end
