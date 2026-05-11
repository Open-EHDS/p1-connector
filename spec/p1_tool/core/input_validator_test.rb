# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Core::InputValidator do
  let(:operation_kinds) { P1Tool::Application::Dispatcher.supported_operation_kinds }

  describe '.validate' do
    it 'returns normalized input for supported operation_kind' do
      input = fixture_json('runtime', 'register_encounter_input.json').merge(
        'options' => { 'attempt' => 1 }
      )

      result = P1Tool::Core::InputValidator.validate(
        input,
        operation_kinds: operation_kinds
      )

      assert_equal 'register-encounter-task-1', result[:task_id]
      assert_equal 'register_encounter', result[:operation_kind]
      assert_equal '75061134485', result.dig(:payload, :patient, :pesel)
      assert_equal({ attempt: 1 }, result[:options])
    end

    it 'rejects unknown operation_kind' do
      error = assert_raises(P1Tool::InputValidationError) do
        P1Tool::Core::InputValidator.validate(
          fixture_json('runtime', 'register_encounter_input.json').merge('operation_kind' => 'unknown'),
          operation_kinds: operation_kinds
        )
      end

      assert_equal ['must be one of: register_encounter, register_procedure, register_condition'], error.details[:operation_kind]
    end

    it 'rejects missing required keys' do
      input = fixture_json('runtime', 'invalid_input_missing_operation_kind.json')
              .merge('operation_kind' => 'register_encounter')
              .except('task_id')

      error = assert_raises(P1Tool::InputValidationError) do
        P1Tool::Core::InputValidator.validate(
          input,
          operation_kinds: operation_kinds
        )
      end

      assert_equal ['is missing'], error.details[:task_id]
    end
  end
end
