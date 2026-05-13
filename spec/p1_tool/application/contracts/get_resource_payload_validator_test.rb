# frozen_string_literal: true

require_relative '../../../test_helper'

describe P1Tool::Application::Contracts::GetResource::PayloadValidator do
  let(:validator) { P1Tool::Application::Contracts::GetResource::PayloadValidator.new }
  let(:payload) { fixture_json('runtime', 'get_resource_input.json').fetch('payload') }

  it 'normalizes valid payload with string keys' do
    result = validator.validate!(payload: payload)

    assert_equal 'LEK', result.dig(:doctor, :profession_code)
    assert_equal 'Patient', result.dig(:resource, :resource_type)
  end

  it 'reports missing doctor and resource sections' do
    error = assert_raises(P1Tool::InputValidationError) do
      validator.validate!(payload: {})
    end

    assert_equal ['must be provided'], error.details.dig(:doctor, :base)
    assert_equal ['must be provided'], error.details.dig(:resource, :base)
  end

  it 'reports blank doctor and resource attributes' do
    error = assert_raises(P1Tool::InputValidationError) do
      validator.validate!(
        payload: {
          doctor: { name: '', profession_code: '', npwz: '', pesel: '' },
          resource: { resource_type: '', resource_id: '' }
        }
      )
    end

    assert_equal ['must be filled'], error.details.dig(:doctor, :name)
    assert_equal ['must be filled'], error.details.dig(:doctor, :profession_code)
    assert_equal ['must include npwz or pesel'], error.details.dig(:doctor, :base)
    assert_equal ['must be filled'], error.details.dig(:resource, :resource_type)
    assert_equal ['must be filled'], error.details.dig(:resource, :resource_id)
  end

  it 'reports unsupported doctor profession code' do
    error = assert_raises(P1Tool::InputValidationError) do
      validator.validate!(
        payload: payload.merge(
          'doctor' => payload.fetch('doctor').merge('profession_code' => 'BOGUS')
        )
      )
    end

    assert_includes error.details.dig(:doctor, :profession_code).first, 'must be one of:'
  end
end
