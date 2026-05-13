# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Application::Dispatcher do
  describe '.call' do
    let(:config) { runtime_config_for('/tmp/p1-tool') }

    it 'invokes register_encounter operation' do
      result = with_fake_p1_client_factory do
        P1Tool::Application::Dispatcher.call_with_config(
          {
            task_id: 'task-register-encounter-1',
            operation_kind: 'register_encounter',
            payload: fixture_json('runtime', 'register_encounter_input.json').fetch('payload')
          },
          config: config
        )
      end

      assert_equal 'Encounter', result[:resource_type]
      assert_equal 'stub-patient-75061134485', result[:patient_reference_id]
      refute result.key?(:xml)
    end

    it 'invokes register_procedure operation' do
      result = with_fake_p1_client_factory do
        P1Tool::Application::Dispatcher.call_with_config(
          {
            task_id: 'task-register-procedure-1',
            operation_kind: 'register_procedure',
            payload: fixture_json('runtime', 'register_procedure_input.json').fetch('payload')
          },
          config: config
        )
      end

      assert_equal 'Procedure', result[:resource_type]
      assert_equal 'enc-123', result[:encounter_reference_id]
      assert_equal 'stub-patient-75061134485', result[:patient_reference_id]
    end

    it 'invokes register_condition operation' do
      result = with_fake_p1_client_factory do
        P1Tool::Application::Dispatcher.call_with_config(
          {
            task_id: 'task-register-condition-1',
            operation_kind: 'register_condition',
            payload: fixture_json('runtime', 'register_condition_input.json').fetch('payload')
          },
          config: config
        )
      end

      assert_equal 'Condition', result[:resource_type]
      assert_equal 'enc-123', result[:encounter_reference_id]
      assert_equal 'stub-patient-75061134485', result[:patient_reference_id]
    end

    it 'invokes register_provenance operation' do
      generator = Struct.new(:value) do
        def call
          value
        end
      end.new
      generator.value = 'c2lnbmF0dXJl'

      result = with_fake_p1_client_factory do
        with_singleton_stub(
          P1Tool::Application::Integrations::SignatureService::GenerateSignature,
          :new,
          ->(**_kwargs) { generator }
        ) do
          P1Tool::Application::Dispatcher.call_with_config(
            {
              task_id: 'task-register-provenance-1',
              operation_kind: 'register_provenance',
              payload: fixture_json('runtime', 'register_provenance_input.json').fetch('payload')
            },
            config: config
          )
        end
      end

      assert_equal 'Provenance', result[:resource_type]
      assert_equal 4, result[:targets].size
      assert_equal 'stub-provenance-1', result.dig(:submission, :reference_id)
    end

    {
      'Patient' => 'pat-123',
      'Encounter' => 'enc-123',
      'Procedure' => 'proc-123',
      'Condition' => 'cond-123',
      'Provenance' => 'prov-123'
    }.each do |resource_type, reference_id|
      it "invokes get_resource for #{resource_type}" do
        result = with_fake_p1_client_factory do
          P1Tool::Application::Dispatcher.call_with_config(
            {
              task_id: "task-get-resource-#{resource_type.downcase}-1",
              operation_kind: 'get_resource',
              payload: fixture_json('runtime', 'get_resource_input.json').fetch('payload').merge(
                'resource' => {
                  'resource_type' => resource_type,
                  'resource_id' => reference_id,
                  'version_id' => '1'
                }
              )
            },
            config: config
          )
        end

        assert_equal resource_type, result[:resource_type]
        assert_equal reference_id, result[:reference_id]
        assert_includes result[:xml], "<#{resource_type}"
      end
    end

    {
      'Encounter' => 'enc-123',
      'Procedure' => 'proc-123',
      'Condition' => 'cond-123',
      'Provenance' => 'prov-123'
    }.each do |resource_type, reference_id|
      it "invokes destroy_resource for #{resource_type}" do
        result = with_fake_p1_client_factory do
          P1Tool::Application::Dispatcher.call_with_config(
            {
              task_id: "task-destroy-resource-#{resource_type.downcase}-1",
              operation_kind: 'destroy_resource',
              payload: fixture_json('runtime', 'destroy_resource_input.json').fetch('payload').merge(
                'resource' => {
                  'resource_type' => resource_type,
                  'resource_id' => reference_id
                }
              )
            },
            config: config
          )
        end

        assert_equal resource_type, result[:resource_type]
        assert_equal reference_id, result[:reference_id]
        assert_equal 200, result[:response_status]
      end
    end

    it 'rejects unsupported operation_kind' do
      error = assert_raises(P1Tool::InputValidationError) do
        P1Tool::Application::Dispatcher.call(
          task_id: 'task-1',
          operation_kind: 'not_supported',
          payload: {}
        )
      end

      assert_equal [
        'must be one of: register_encounter, register_procedure, register_condition, register_provenance, ' \
        'get_resource, destroy_resource'
      ], error.details[:operation_kind]
    end
  end
end
