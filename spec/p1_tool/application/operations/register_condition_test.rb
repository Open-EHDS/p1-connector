# frozen_string_literal: true

require_relative '../../../test_helper'

describe P1Tool::Application::Operations::RegisterCondition do
  let(:operation_class) { P1Tool::Application::Operations::RegisterCondition }
  let(:input) { fixture_json('runtime', 'register_condition_input.json') }
  let(:config) { runtime_config_for('/tmp/p1-tool') }

  describe '.call' do
    it 'returns condition metadata using fake P1 client' do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload')
        },
        config: config,
        p1_client: build_fake_p1_client
      )

      assert_equal 'Condition', result[:resource_type]
      assert_equal 'enc-123', result[:encounter_reference_id]
      assert_equal 'stub-patient-75061134485', result[:patient_reference_id]
      assert_equal 'found', result.dig(:patient_resolution, :status)
      assert_equal 'created', result.dig(:submission, :status)
      assert_equal 'stub-condition-1', result.dig(:submission, :reference_id)
    end

    it 'updates condition when resource_id is present' do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload').merge(
            'condition' => input.fetch('payload').fetch('condition').merge('resource_id' => 'cond-123')
          )
        },
        config: config,
        p1_client: build_fake_p1_client
      )

      assert_equal 'updated', result.dig(:submission, :status)
      assert_equal 'cond-123', result.dig(:submission, :reference_id)
    end

    it 'accepts concurrent diagnosis category' do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload').merge(
            'condition' => input.fetch('payload').fetch('condition').merge('category' => 'concurrent')
          )
        },
        config: config,
        p1_client: build_fake_p1_client
      )

      assert_equal 'created', result.dig(:submission, :status)
      assert_equal 'stub-condition-1', result.dig(:submission, :reference_id)
    end

    it 'rejects invalid category, element_code and recorded_date' do
      error = assert_raises(P1Tool::InputValidationError) do
        operation_class.call(
          {
            task_id: 'task-1',
            operation_kind: 'register_condition',
            payload: {
              patient: {
                pesel: '75061134485',
                first_name: 'Dorota',
                last_name: 'Kalandyk'
              },
              doctor: {
                profession_code: 'LEK',
                name: 'Adam739 Leczniczy',
                npwz: '5691489'
              },
              encounter: {
                resource_id: 'enc-123'
              },
              condition: {
                icd_10_code: 'K02',
                icd_10_name: 'Prochnica zebow',
                category: 'other',
                element_code: 'unknown',
                recorded_date: 'not-a-date'
              }
            }
          },
          config: config
        )
      end

      assert_equal ['must be one of: main, concurrent'], error.details.dig(:condition, :category)
      assert_equal ['must be a valid ISO8601 date time'], error.details.dig(:condition, :recorded_date)
      assert_equal ['is not present in P1 element catalog'], error.details.dig(:condition, :element_code)
    end
  end
end
