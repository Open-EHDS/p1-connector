# frozen_string_literal: true

require_relative '../../../test_helper'

describe P1Tool::Application::Operations::RegisterEncounter do
  let(:operation_class) { P1Tool::Application::Operations::RegisterEncounter }
  let(:input) { fixture_json('runtime', 'register_encounter_input.json') }
  let(:config) { runtime_config_for('/tmp/p1-tool') }

  describe '.call' do
    it 'returns encounter metadata and uses patient resolver stub' do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload')
        },
        config: config
      )

      assert_equal 'Encounter', result[:resource_type]
      assert_match(/\A[\h-]{36}\z/, result[:encounter_identifier])
      assert_match(/\A[\h-]{36}\z/, result[:episode_identifier])
      assert_equal 'stub-patient-75061134485', result[:patient_reference_id]
      assert_equal 'stubbed', result.dig(:patient_resolution, :status)
      assert_equal 'stubbed', result.dig(:submission, :status)
      refute result.key?(:xml)
      refute result.key?(:debug_xml_path)
    end

    it 'rejects payload without doctor identifier' do
      error = assert_raises(P1Tool::InputValidationError) do
        operation_class.call(
          {
            task_id: 'task-1',
            operation_kind: 'register_encounter',
            payload: {
              patient: {
                pesel: '75061134485',
                first_name: 'Dorota',
                last_name: 'Kalandyk'
              },
              doctor: {
                profession_code: 'LEK',
                name: 'Dorota358 Leczniczy'
              },
              encounter: {
                start_time: '2021-09-28T13:00:00+02:00',
                end_time: '2021-09-28T12:30:00+02:00'
              }
            }
          },
          config: config
        )
      end

      assert_equal ['must include npwz or pesel'], error.details.dig(:doctor, :base)
      assert_equal ['must be greater than or equal to start_time'], error.details.dig(:encounter, :end_time)
    end
  end
end
