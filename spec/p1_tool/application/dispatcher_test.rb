# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Application::Dispatcher do
  describe '.call' do
    let(:config) { runtime_config_for('/tmp/p1-tool') }

    it 'invokes register_encounter operation' do
      result = P1Tool::Application::Dispatcher.call_with_config(
        {
          task_id: 'task-register-encounter-1',
          operation_kind: 'register_encounter',
          payload: fixture_json('runtime', 'register_encounter_input.json').fetch('payload')
        },
        config: config
      )

      assert_equal 'Encounter', result[:resource_type]
      assert_equal 'stub-patient-75061134485', result[:patient_reference_id]
      refute result.key?(:xml)
    end

    it 'rejects unsupported operation_kind' do
      error = assert_raises(P1Tool::InputValidationError) do
        P1Tool::Application::Dispatcher.call(
          task_id: 'task-1',
          operation_kind: 'not_supported',
          payload: {}
        )
      end

      assert_equal ['must be one of: register_encounter'], error.details[:operation_kind]
    end
  end
end
