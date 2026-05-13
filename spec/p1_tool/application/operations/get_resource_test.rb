# frozen_string_literal: true

require_relative '../../../test_helper'

describe P1Tool::Application::Operations::GetResource do
  let(:operation_class) { P1Tool::Application::Operations::GetResource }
  let(:config) { runtime_config_for('/tmp/p1-tool') }
  let(:input) { fixture_json('runtime', 'get_resource_input.json') }

  {
    'Patient' => %w[pat-123 7],
    'Encounter' => %w[enc-123 1],
    'Procedure' => %w[proc-123 1],
    'Condition' => %w[cond-123 1],
    'Provenance' => %w[prov-123 1]
  }.each do |resource_type, (reference_id, version_id)|
    it "returns xml for #{resource_type}" do
      result = operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload').merge(
            'resource' => {
              'resource_type' => resource_type,
              'resource_id' => reference_id,
              'version_id' => version_id
            }
          )
        },
        config: config,
        p1_client: build_fake_p1_client
      )

      assert_equal resource_type, result[:resource_type]
      assert_equal reference_id, result[:reference_id]
      assert_equal version_id, result[:version_id]
      assert_equal 'application/fhir+xml', result[:content_type]
      assert_includes result[:xml], "<#{resource_type}"
    end
  end

  it 'rejects unsupported resource_type' do
    error = assert_raises(P1Tool::InputValidationError) do
      operation_class.call(
        {
          task_id: input.fetch('task_id'),
          operation_kind: input.fetch('operation_kind'),
          payload: input.fetch('payload').merge(
            'resource' => {
              'resource_type' => 'Observation',
              'resource_id' => 'obs-123'
            }
          )
        },
        config: config,
        p1_client: build_fake_p1_client
      )
    end

    assert_equal ['must be one of: Patient, Encounter, Procedure, Condition, Provenance'],
                 error.details.dig(:resource, :resource_type)
  end
end
