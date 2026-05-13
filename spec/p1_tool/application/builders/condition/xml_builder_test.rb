# frozen_string_literal: true

require 'nokogiri'
require_relative '../../../../test_helper'

describe P1Tool::Application::Builders::Condition::XmlBuilder do
  let(:builder_class) { P1Tool::Application::Builders::Condition::XmlBuilder }
  let(:subject) { runtime_subject_config }
  let(:validated_payload) do
    P1Tool::Application::Contracts::RegisterCondition::PayloadValidator.new.validate!(
      payload: fixture_json('runtime', 'register_condition_input.json').fetch('payload'),
      subject:
    )
  end
  let(:data) do
    P1Tool::Application::Builders::Condition::DataBuilder.new(payload: validated_payload, subject:).call.merge(
      patient_reference_id: 'pat-123'
    )
  end

  describe '#call' do
    it 'defaults category to main and builds condition xml with location extension and bodySite' do
      xml = builder_class.new(data).call

      document = Nokogiri::XML(xml)

      assert_equal 'Condition', document.root.name
      encounter_reference = value_at(document, '//*[local-name()="encounter"]/*[local-name()="reference"]')

      assert_equal 'enc-123', encounter_reference.sub('Encounter/', '')
      assert_equal data[:location_identifier_value], value_at(
        document,
        '//*[local-name()="extension"]/*[local-name()="valueIdentifier"]/*[local-name()="value"]'
      )
      assert_equal '85',
                   value_at(document, '//*[local-name()="bodySite"]/*[local-name()="coding"]/*[local-name()="code"]')
      assert_equal 'main',
                   value_at(document, '//*[local-name()="category"]/*[local-name()="coding"]/*[local-name()="code"]')
      assert_equal 'Główne', value_at(
        document,
        '//*[local-name()="category"]/*[local-name()="coding"]/*[local-name()="display"]'
      )
    end

    it 'writes concurrent category when provided' do
      payload = Marshal.load(Marshal.dump(validated_payload))
      payload[:condition][:category] = 'concurrent'
      xml = builder_class.new(
        P1Tool::Application::Builders::Condition::DataBuilder.new(payload:,
                                                                  subject:).call.merge(patient_reference_id: 'pat-123')
      ).call

      document = Nokogiri::XML(xml)

      assert_equal 'concurrent',
                   value_at(document, '//*[local-name()="category"]/*[local-name()="coding"]/*[local-name()="code"]')
      assert_equal 'Współistniejące',
                   value_at(document, '//*[local-name()="category"]/*[local-name()="coding"]/*[local-name()="display"]')
    end

    it 'omits bodySite when element_code is missing' do
      payload = Marshal.load(Marshal.dump(validated_payload))
      payload[:condition].delete(:element_code)
      xml = builder_class.new(
        P1Tool::Application::Builders::Condition::DataBuilder.new(payload:,
                                                                  subject:).call.merge(patient_reference_id: 'pat-123')
      ).call

      document = Nokogiri::XML(xml)

      assert_nil document.at_xpath('//*[local-name()="bodySite"]')
    end
  end

  def value_at(document, xpath)
    document.at_xpath(xpath)['value']
  end
end
