# frozen_string_literal: true

require_relative '../../../test_helper'

describe P1Tool::Application::Operations::DestroyResource do
  let(:operation_class) { P1Tool::Application::Operations::DestroyResource }
  let(:config) { runtime_config_for('/tmp/p1-tool') }
  let(:input) { fixture_json('runtime', 'destroy_resource_input.json') }

  {
    'Encounter' => 'enc-123',
    'Procedure' => 'proc-123',
    'Condition' => 'cond-123',
    'Provenance' => 'prov-123'
  }.each do |resource_type, reference_id|
    it "deletes #{resource_type}" do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload').merge(
            'resource' => {
              'resource_type' => resource_type,
              'resource_id' => reference_id
            }
          )
        },
        config: config,
        p1_client: build_fake_p1_client
      )

      assert_equal resource_type, result[:resource_type]
      assert_equal reference_id, result[:reference_id]
      assert_equal 200, result[:response_status]
    end
  end

  it 'rejects Patient resource_type' do
    error = assert_raises(P1Tool::InputValidationError) do
      operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload').merge(
            'resource' => {
              'resource_type' => 'Patient',
              'resource_id' => 'pat-123'
            }
          )
        },
        config: config,
        p1_client: build_fake_p1_client
      )
    end

    assert_equal ['must be one of: Encounter, Procedure, Condition, Provenance'],
                 error.details.dig(:resource, :resource_type)
  end
end
