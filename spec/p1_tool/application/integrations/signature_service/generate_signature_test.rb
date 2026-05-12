# frozen_string_literal: true

require_relative '../../../../test_helper'

describe P1Tool::Application::Integrations::SignatureService::GenerateSignature do
  let(:integration_class) { P1Tool::Application::Integrations::SignatureService::GenerateSignature }
  let(:tmpdir) { Dir.mktmpdir }
  let(:config) do
    runtime_config_for(tmpdir).merge(
      certificates: {
        base_path: tmpdir,
        wss: { filename: 'wss.p12', password_env: 'WSS_CERT_PASSWORD' },
        tls: { filename: 'tls.p12', password_env: 'TLS_CERT_PASSWORD' }
      }
    )
  end
  let(:payload) do
    {
      references: [
        { resource_type: 'Patient', reference_id: 'pat-123', version_id: '7' },
        { resource_type: 'Encounter', reference_id: 'enc-123', version_id: '1' }
      ]
    }
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  it 'builds documents payload from P1 resources and returns base64 signature' do
    signature_client = Class.new do
      attr_reader :request

      def generate_signature(documents:)
        @request = {
          documents:
        }
        {
          'document' => '<Signature/>',
          'documentBase64' => 'PFNpZ25hdHVyZS8+'
        }
      end
    end.new

    p1_client = Class.new do
      attr_reader :fetch_requests

      def initialize
        @fetch_requests = []
      end

      def get_resource_xml(resource_type:, reference_id:, version_id: nil)
        @fetch_requests << {
          resource_type:,
          reference_id:,
          version_id:
        }
        {
          status: 200,
          body: "<#{resource_type} id=\"#{reference_id}\" version=\"#{version_id}\"/>",
          headers: { 'Content-Type' => 'application/fhir+xml; charset=UTF-8' }
        }
      end
    end.new

    result = integration_class.new(
      payload:,
      config:,
      client: p1_client,
      signature_client:
    ).call

    assert_equal 'PFNpZ25hdHVyZS8+', result
    assert_equal [
      {
        uri: 'https://isus.ezdrowie.gov.pl/fhir/Patient/pat-123/_history/7',
        mimeType: 'application/fhir+xml',
        content: '<Patient id="pat-123" version="7"/>'
      },
      {
        uri: 'https://isus.ezdrowie.gov.pl/fhir/Encounter/enc-123/_history/1',
        mimeType: 'application/fhir+xml',
        content: '<Encounter id="enc-123" version="1"/>'
      }
    ], signature_client.request[:documents]
    assert_equal [
      { resource_type: 'Patient', reference_id: 'pat-123', version_id: '7' },
      { resource_type: 'Encounter', reference_id: 'enc-123', version_id: '1' }
    ], p1_client.fetch_requests
  end
end
