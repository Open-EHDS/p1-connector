# frozen_string_literal: true

require_relative '../../../test_helper'

describe P1Tool::Gateways::SignatureService::Client do
  let(:client_class) { P1Tool::Gateways::SignatureService::Client }

  it 'posts json request to xades-detached and returns parsed response' do
    captured = {}
    connection = Object.new
    connection.define_singleton_method(:post) do |path, &block|
      request = Struct.new(:headers, :body, keyword_init: true).new(headers: {})
      block.call(request)
      captured[:path] = path
      captured[:headers] = request.headers
      captured[:body] = request.body
      Struct.new(:status, :body, keyword_init: true).new(
        status: 200,
        body: { document: '<Signature/>', documentBase64: 'PFNpZ25hdHVyZS8+' }.to_json
      )
    end

    client = client_class.new(base_url: 'http://signature-tool:8080', connection_factory: -> { connection })

    result = client.generate_signature(
      documents: [
        {
          uri: 'https://isus.ezdrowie.gov.pl/fhir/Patient/1/_history/7',
          mimeType: 'application/fhir+xml',
          content: '<Patient xmlns="http://hl7.org/fhir"/>'
        }
      ]
    )

    assert_equal '<Signature/>', result['document']
    assert_equal 'PFNpZ25hdHVyZS8+', result['documentBase64']
    assert_equal 'api/v1/signatures/xades-detached', captured[:path]
    assert_equal 'application/json', captured[:headers]['Content-Type']
    assert_equal 'application/json', captured[:headers]['Accept']
    assert_equal(
      {
        'documents' => [
          {
            'uri' => 'https://isus.ezdrowie.gov.pl/fhir/Patient/1/_history/7',
            'mimeType' => 'application/fhir+xml',
            'content' => '<Patient xmlns="http://hl7.org/fhir"/>'
          }
        ]
      },
      JSON.parse(captured[:body])
    )
  end
end
