# frozen_string_literal: true

require_relative '../../../test_helper'

describe P1Tool::Application::Contracts::RegisterEncounter::PayloadValidator do
  let(:validator) { P1Tool::Application::Contracts::RegisterEncounter::PayloadValidator.new }
  let(:payload) { fixture_json('runtime', 'register_encounter_input.json').fetch('payload') }
  let(:subject) { runtime_subject_config }

  it 'accepts practice subject when medical chamber is present' do
    result = validator.validate!(
      payload: payload,
      subject: subject.merge(is_practice: true, medical_chamber: 'NIL')
    )

    assert_equal 'LEK', result.dig(:doctor, :profession_code)
  end

  it 'requires medical chamber for practice subject' do
    error = assert_raises(P1Tool::ConfigurationError) do
      validator.validate!(
        payload: payload,
        subject: subject.merge(is_practice: true, medical_chamber: '')
      )
    end

    assert_equal 'subject.medical_chamber is required for practice encounter XML', error.message
  end

  it 'reports invalid explicit medical profession code' do
    error = assert_raises(P1Tool::InputValidationError) do
      validator.validate!(
        payload: payload.merge(
          'doctor' => payload.fetch('doctor').merge('medical_profession_code' => '999')
        ),
        subject: subject
      )
    end

    assert_includes error.details.dig(:doctor, :medical_profession_code).first, 'must be one of:'
  end

  it 'reports medical profession code inconsistent with profession mapping' do
    error = assert_raises(P1Tool::InputValidationError) do
      validator.validate!(
        payload: payload.merge(
          'doctor' => payload.fetch('doctor').merge('medical_profession_code' => '50')
        ),
        subject: subject
      )
    end

    assert_equal ['must match profession_code mapping: 11'], error.details.dig(:doctor, :medical_profession_code)
  end

  it 'accepts matching class_name and complete payer identifier' do
    result = validator.validate!(
      payload: payload.merge(
        'encounter' => payload.fetch('encounter').merge('class_name' => 'Porada'),
        'payer' => {
          'identifier_system' => 'urn:oid:1.2.3',
          'identifier_value' => 'payer-1'
        }
      ),
      subject: subject
    )

    assert_equal 'Porada', result.dig(:encounter, :class_name)
    assert_equal 'payer-1', result.dig(:payer, :identifier_value)
  end

  it 'reports class_name inconsistent with class_code display' do
    error = assert_raises(P1Tool::InputValidationError) do
      validator.validate!(
        payload: payload.merge(
          'encounter' => payload.fetch('encounter').merge('class_name' => 'hospitalizacja')
        ),
        subject: subject
      )
    end

    assert_equal ['must match class_code display: Porada'], error.details.dig(:encounter, :class_name)
  end

  it 'reports incomplete payer identifier pair' do
    error = assert_raises(P1Tool::InputValidationError) do
      validator.validate!(
        payload: payload.merge('payer' => { 'identifier_system' => 'urn:oid:1.2.3' }),
        subject: subject
      )
    end

    assert_equal ['must be provided together with identifier_value'], error.details.dig(:payer, :identifier_system)
    assert_equal ['must be provided together with identifier_system'], error.details.dig(:payer, :identifier_value)
  end

  it 'reports invalid encounter period timestamps' do
    error = assert_raises(P1Tool::InputValidationError) do
      validator.validate!(
        payload: payload.merge(
          'encounter' => payload.fetch('encounter').merge(
            'start_time' => 'not-a-date',
            'end_time' => 'also-not-a-date'
          )
        ),
        subject: subject
      )
    end

    assert_equal ['must be a valid ISO8601 date time'], error.details.dig(:encounter, :start_time)
    assert_equal ['must be a valid ISO8601 date time'], error.details.dig(:encounter, :end_time)
  end
end
