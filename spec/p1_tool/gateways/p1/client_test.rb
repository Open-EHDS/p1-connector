# frozen_string_literal: true

require 'openssl'
require_relative '../../../test_helper'

describe P1Tool::Gateways::P1::Client do
  let(:config) { runtime_config_for('/tmp/p1-tool').merge(p1: { environment: 'integration' }) }
  let(:payload) do
    P1Tool::Application::Contracts::RegisterEncounter::PayloadValidator.new.validate!(
      payload: fixture_json('runtime', 'register_encounter_input.json').fetch('payload'),
      subject: runtime_subject_config
    )
  end
  let(:subject) { runtime_subject_config }
  let(:doctor) { payload.fetch(:doctor) }
  let(:response_class) { Struct.new(:status, :headers, :body, keyword_init: true) }
  let(:transport_class) do
    Class.new do
      attr_reader :requests

      def initialize(response_class)
        @response_class = response_class
        @calls = 0
        @requests = []
      end

      def request(**request)
        @calls += 1
        @requests << request
        response_for(request)
      end

      private

      attr_reader :response_class

      def response_for(request) = response_for_call_count || unexpected_request!(request)

      def response_for_call_count
        {
          1 => token_response,
          2 => patient_response,
          3 => encounter_response,
          4 => encounter_xml_response
        }[@calls]
      end

      def token_response
        response_class.new(status: 200, headers: {}, body: { 'accessToken' => 'replay-access-token' })
      end

      def patient_response
        response_class.new(
          status: 200,
          headers: {},
          body: { 'resourceType' => 'Bundle', 'total' => 1, 'entry' => [{ 'resource' => { 'id' => '1290' } }] }
        )
      end

      def encounter_response
        response_class.new(
          status: 201,
          headers: {},
          body: { 'resourceType' => 'Encounter', 'id' => '261728421645691904', 'meta' => { 'versionId' => '1' } }
        )
      end

      def encounter_xml_response
        response_class.new(
          status: 200,
          headers: { 'Content-Type' => 'application/fhir+xml' },
          body: '<Encounter id="261728421645691904" version="1"/>'
        )
      end

      def unexpected_request!(request)
        raise "Unexpected request ##{@calls}: #{request[:method]} #{request[:path]}"
      end
    end
  end
  let(:transport) { transport_class.new(response_class) }
  let(:key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:bundle) { Struct.new(:key, :certificate, :ca_certs).new(key, nil, []) }
  let(:token_builder) { P1Tool::Gateways::P1::TokenBuilder.new(subject:, doctor:, clock: -> { Time.utc(2026, 5, 6, 10, 0, 0) }) }
  let(:access_token_provider) do
    P1Tool::Gateways::P1::AccessTokenProvider.new(
      config:,
      transport:,
      token_builder:,
      wss_bundle: bundle
    )
  end
  let(:client) do
    P1Tool::Gateways::P1::Client.new(
      transport:,
      access_token_provider:
    )
  end

  it 'fetches token, finds patient and creates encounter through injected transport' do
    log_path = File.join(Dir.mktmpdir, 'audit.jsonl')
    audit_log = P1Tool::Adapters::AuditLog.new(log_path, clock: -> { Time.utc(2026, 5, 6, 10, 0, 0) })
    context = P1Tool::Runtime::ExecutionContext.new(
      transport_id: 'transport-1',
      task_id: 'task-1',
      operation_kind: 'register_encounter',
      attempt: 1,
      correlation_id: 'corr-1',
      config_version: 'cfg-v1',
      runtime_mode: 'run_once',
      source_path: '/tmp/input.json'
    )

    patient_response = nil
    encounter_response = nil
    encounter_xml_response = nil

    P1Tool::Runtime::CurrentExecution.with(context:, audit_log:) do
      patient_response = client.find_patient(payload:)
      encounter_response = client.create_resource(resource_type: 'Encounter', xml: '<Encounter/>')
      encounter_xml_response = client.get_resource_xml(
        resource_type: 'Encounter',
        reference_id: '261728421645691904',
        version_id: '1'
      )
    end

    audit_lines = File.readlines(log_path, chomp: true).map { |line| JSON.parse(line) }
    token_event = audit_lines.find { |entry| entry.fetch('event_type') == 'p1_access_token_acquired' }

    assert_equal 'replay-access-token', client.token
    assert_equal 'application/x-www-form-urlencoded', transport.requests[0].dig(:headers, 'Content-Type')
    assert_equal 'application/json', transport.requests[0].dig(:headers, 'Accept')
    assert_equal 200, token_event.dig('metadata', 'http_status')
    assert_equal 'integration', token_event.dig('metadata', 'p1_environment')
    assert_equal '1290', patient_response.dig(:body, 'entry', 0, 'resource', 'id')
    assert_equal '261728421645691904', encounter_response[:reference_id]
    assert_equal '1', encounter_response[:version_id]
    assert_equal 'application/fhir+xml', transport.requests[3].dig(:headers, 'Accept')
    assert_equal 'fhir/Encounter/261728421645691904/_history/1', transport.requests[3][:path]
    assert_equal '<Encounter id="261728421645691904" version="1"/>', encounter_xml_response[:body]
  end

  it 'raises business error with parsed response body details on non-success response' do
    error_transport = Class.new do
      def initialize
        @calls = 0
      end

      def request(**)
        @calls += 1

        if @calls == 1
          return Struct.new(:status, :headers, :body, keyword_init: true).new(
            status: 200,
            headers: {},
            body: { 'accessToken' => 'replay-access-token' }
          )
        end

        Struct.new(:status, :headers, :body, keyword_init: true).new(
          status: 422,
          headers: { 'Content-Type' => 'application/fhir+json' },
          body: { 'issue' => [{ 'diagnostics' => 'invalid payload' }] }
        )
      end
    end.new

    error_access_token_provider = P1Tool::Gateways::P1::AccessTokenProvider.new(
      config:,
      transport: error_transport,
      token_builder:,
      wss_bundle: bundle
    )

    client = P1Tool::Gateways::P1::Client.new(
      transport: error_transport,
      access_token_provider: error_access_token_provider
    )

    error = assert_raises(P1Tool::BusinessError) do
      client.find_patient(payload:)
    end

    assert_equal 422, error.details[:http_status]
    assert_equal [{ 'diagnostics' => 'invalid payload' }], error.details.dig(:body, 'issue')
  end
end
