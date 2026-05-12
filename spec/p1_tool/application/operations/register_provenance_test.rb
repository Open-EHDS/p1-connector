# frozen_string_literal: true

require_relative '../../../test_helper'

describe P1Tool::Application::Operations::RegisterProvenance do
  let(:operation_class) { P1Tool::Application::Operations::RegisterProvenance }
  let(:input) { fixture_json('runtime', 'register_provenance_input.json') }
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

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe '.call' do
    it 'returns provenance metadata using fake P1 client and stub signature service' do
      signature_client_class = Class.new do
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
      end

      signature_client = signature_client_class.new

      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload')
        },
        config: config,
        p1_client: build_fake_p1_client,
        signature_client:
      )

      assert_equal 'Provenance', result[:resource_type]
      assert_equal 4, result[:targets].size
      assert_equal 'created', result.dig(:submission, :status)
      assert_equal 'stub-provenance-1', result.dig(:submission, :reference_id)
      assert_equal 4, signature_client.request[:documents].size
      assert_equal 'https://isus.ezdrowie.gov.pl/fhir/Patient/pat-123/_history/7',
                   signature_client.request[:documents].first[:uri]
      assert_equal 'application/fhir+xml', signature_client.request[:documents].first[:mimeType]
      assert_includes signature_client.request[:documents].first[:content], '<Patient'
    end

    it 'rejects payload without Patient and Encounter references' do
      error = assert_raises(P1Tool::InputValidationError) do
        operation_class.call(
          {
            task_id: 'task-1',
            operation_kind: 'register_provenance',
            payload: {
              doctor: {
                profession_code: 'LEK',
                name: 'Adam739 Leczniczy',
                npwz: '5691489'
              },
              references: [
                { resource_type: 'Procedure', reference_id: 'proc-1', version_id: '1' }
              ],
              provenance: {
                recorded_at: '2021-09-28T13:00:00+02:00'
              }
            }
          },
          config: config
        )
      end

      assert_equal ['must include Patient reference'], error.details.dig(:references, :base)[0, 1]
      assert_equal ['must include Encounter reference'], error.details.dig(:references, :base)[1, 1]
    end
  end
end
