# frozen_string_literal: true

require_relative '../../../test_helper'

describe P1Tool::Application::Operations::RegisterProcedure do
  let(:operation_class) { P1Tool::Application::Operations::RegisterProcedure }
  let(:input) { fixture_json('runtime', 'register_procedure_input.json') }
  let(:config) { runtime_config_for('/tmp/p1-tool') }

  describe '.call' do
    it 'returns procedure metadata using fake P1 client' do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload')
        },
        config: config,
        p1_client: build_fake_p1_client
      )

      assert_equal 'Procedure', result[:resource_type]
      assert_equal 'enc-123', result[:encounter_reference_id]
      assert_equal 'stub-patient-75061134485', result[:patient_reference_id]
      assert_equal 'found', result.dig(:patient_resolution, :status)
      assert_equal 'created', result.dig(:submission, :status)
      assert_equal 'stub-procedure-1', result.dig(:submission, :reference_id)
    end

    it 'updates procedure when resource_id is present' do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload').merge(
            'procedure' => input.fetch('payload').fetch('procedure').merge('resource_id' => 'proc-123')
          )
        },
        config: config,
        p1_client: build_fake_p1_client
      )

      assert_equal 'updated', result.dig(:submission, :status)
      assert_equal 'proc-123', result.dig(:submission, :reference_id)
    end

    it 'rejects invalid element_code and procedure period' do
      error = assert_raises(P1Tool::InputValidationError) do
        operation_class.call(
          {
            task_id: 'task-1',
            operation_kind: 'register_procedure',
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
              procedure: {
                icd_9_code: '23.1108',
                icd_9_name: 'Wypełnienie ubytku korony zęba mlecznego',
                element_code: 'unknown',
                start_time: '2021-09-28T13:00:00+02:00',
                end_time: '2021-09-28T12:30:00+02:00'
              }
            }
          },
          config: config
        )
      end

      assert_equal ['must be greater than or equal to start_time'], error.details.dig(:procedure, :end_time)
      assert_equal ['is not present in P1 element catalog'], error.details.dig(:procedure, :element_code)
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
  end
end
