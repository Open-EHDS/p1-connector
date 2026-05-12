# frozen_string_literal: true

require_relative '../../../../../test_helper'

describe P1Tool::Application::Integrations::P1::Patient::FindOrCreate do
  let(:payload) do
    P1Tool::Application::Contracts::RegisterEncounter::PayloadValidator.new.validate!(
      payload: fixture_json('runtime', 'register_encounter_input.json').fetch('payload'),
      subject: runtime_subject_config
    )
  end

  let(:client_class) do
    Class.new do
      attr_reader :created_xml

      def initialize
        @created_xml = nil
      end

      def find_patient(payload:)
        { status: 200, body: { 'resourceType' => 'Bundle', 'total' => 0, 'entry' => [] } }
      end

      def create_resource(resource_type:, xml:)
        @created_xml = xml
        { status: 201, reference_id: 'new-patient-1', version_id: '1' }
      end
    end
  end

  it 'creates patient when search result is empty' do
    client = client_class.new
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

    result = nil
    P1Tool::Runtime::CurrentExecution.with(context:, audit_log:) do
      result = P1Tool::Application::Integrations::P1::Patient::FindOrCreate.new(
        payload:,
        subject: runtime_subject_config,
        client:
      ).call
    end

    events = File.readlines(log_path, chomp: true).map { |line| JSON.parse(line) }

    assert_equal 'created', result[:status]
    assert_equal 'new-patient-1', result[:patient_reference_id]
    assert_equal '1', result[:patient_version_id]
    assert_equal %w[p1_patient_lookup_finished p1_patient_created], events.map { |event| event['event_type'] }
    assert_equal false, events[0].dig('metadata', 'found')
    assert_equal 'new-patient-1', events[1].dig('metadata', 'patient_reference_id')
    assert_equal '1', events[1].dig('metadata', 'patient_version_id')
    assert_includes client.created_xml, '<Patient'
    assert_includes client.created_xml, 'PLPatient'
  end
end
