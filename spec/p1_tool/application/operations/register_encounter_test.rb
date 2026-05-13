# frozen_string_literal: true

require_relative '../../../test_helper'

describe P1Tool::Application::Operations::RegisterEncounter do
  let(:operation_class) { P1Tool::Application::Operations::RegisterEncounter }
  let(:input) { fixture_json('runtime', 'register_encounter_input.json') }
  let(:config) { runtime_config_for('/tmp/p1-tool') }

  describe '.call' do
    it 'returns encounter metadata using fake P1 client' do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload')
        },
        config: config,
        p1_client: build_fake_p1_client
      )

      assert_equal 'Encounter', result[:resource_type]
      assert_match(/\A[\h-]{36}\z/, result[:encounter_identifier])
      assert_match(/\A[\h-]{36}\z/, result[:episode_identifier])
      assert_equal 'stub-patient-75061134485', result[:patient_reference_id]
      assert_equal 'found', result.dig(:patient_resolution, :status)
      assert_equal '7', result.dig(:patient_resolution, :patient_version_id)
      assert_equal 'created', result.dig(:submission, :status)
      refute result.key?(:xml)
      refute result.key?(:debug_xml_path)
    end

    it 'updates encounter when resource_id is present' do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload').merge(
            'encounter' => input.fetch('payload').fetch('encounter').merge('resource_id' => 'enc-123')
          )
        },
        config: config,
        p1_client: build_fake_p1_client
      )

      assert_equal 'stub-patient-75061134485', result[:patient_reference_id]
      assert_equal 'found', result.dig(:patient_resolution, :status)
      assert_equal '7', result.dig(:patient_resolution, :patient_version_id)
      assert_equal 'updated', result.dig(:submission, :status)
      assert_equal 'enc-123', result.dig(:submission, :reference_id)
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
                class_code: '4',
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

    it 'rejects payload with class_code outside PLMedicalEventClass dictionary' do
      error = assert_raises(P1Tool::InputValidationError) do
        operation_class.call(
          {
            task_id: input.fetch('task_id'),
            operation_kind: input.fetch('operation_kind'),
            payload: input.fetch('payload').merge(
              'encounter' => input.fetch('payload').fetch('encounter').merge('class_code' => '999')
            )
          },
          config: config
        )
      end

      assert_equal ['is not present in PLMedicalEventClass dictionary'], error.details.dig(:encounter, :class_code)
    end

    it 'rejects payload when profession_code has no automatic medical profession mapping' do
      error = assert_raises(P1Tool::InputValidationError) do
        operation_class.call(
          {
            task_id: input.fetch('task_id'),
            operation_kind: input.fetch('operation_kind'),
            payload: input.fetch('payload').merge(
              'doctor' => input.fetch('payload').fetch('doctor').merge('profession_code' => 'PROF')
            )
          },
          config: config
        )
      end

      assert_equal ['must be provided when profession_code cannot be mapped automatically'],
                   error.details.dig(:doctor, :medical_profession_code)
    end

    it 'rejects unsupported profession_code without raising runtime error' do
      error = assert_raises(P1Tool::InputValidationError) do
        operation_class.call(
          {
            task_id: input.fetch('task_id'),
            operation_kind: input.fetch('operation_kind'),
            payload: input.fetch('payload').merge(
              'doctor' => input.fetch('payload').fetch('doctor').merge('profession_code' => 'BOGUS')
            )
          },
          config: config
        )
      end

      assert_equal ['must be one of: LEK, FEL, LEKD, PIEL, POL, FARM, RAT, PROF, PADM, ASYS, FIZJO, DIAG, HIGSZKOL'],
                   error.details.dig(:doctor, :profession_code)
    end

    it 'accepts payload with explicit medical_profession_code when profession_code is ambiguous' do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload').merge(
            'doctor' => input.fetch('payload').fetch('doctor').merge(
              'profession_code' => 'PROF',
              'medical_profession_code' => '50'
            )
          )
        },
        config: config,
        p1_client: build_fake_p1_client
      )

      assert_equal 'Encounter', result[:resource_type]
      assert_equal 'created', result.dig(:submission, :status)
    end
  end
end
