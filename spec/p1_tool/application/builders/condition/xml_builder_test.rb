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
      assert_equal 'enc-123', document.at_xpath('//*[local-name()="encounter"]/*[local-name()="reference"]')['value'].sub('Encounter/', '')
      assert_equal data[:location_identifier_value],
                   document.at_xpath('//*[local-name()="extension"]/*[local-name()="valueIdentifier"]/*[local-name()="value"]')['value']
      assert_equal '85', document.at_xpath('//*[local-name()="bodySite"]/*[local-name()="coding"]/*[local-name()="code"]')['value']
      assert_equal 'main', document.at_xpath('//*[local-name()="category"]/*[local-name()="coding"]/*[local-name()="code"]')['value']
      assert_equal 'Główne', document.at_xpath('//*[local-name()="category"]/*[local-name()="coding"]/*[local-name()="display"]')['value']
    end

    it 'writes concurrent category when provided' do
      payload = Marshal.load(Marshal.dump(validated_payload))
      payload[:condition][:category] = 'concurrent'
      xml = builder_class.new(
        P1Tool::Application::Builders::Condition::DataBuilder.new(payload:, subject:).call.merge(patient_reference_id: 'pat-123')
      ).call

      document = Nokogiri::XML(xml)

      assert_equal 'concurrent', document.at_xpath('//*[local-name()="category"]/*[local-name()="coding"]/*[local-name()="code"]')['value']
      assert_equal 'Współistniejące',
                   document.at_xpath('//*[local-name()="category"]/*[local-name()="coding"]/*[local-name()="display"]')['value']
    end

    it 'omits bodySite when element_code is missing' do
      payload = Marshal.load(Marshal.dump(validated_payload))
      payload[:condition].delete(:element_code)
      xml = builder_class.new(
        P1Tool::Application::Builders::Condition::DataBuilder.new(payload:, subject:).call.merge(patient_reference_id: 'pat-123')
      ).call

      document = Nokogiri::XML(xml)

      assert_nil document.at_xpath('//*[local-name()="bodySite"]')
    end
  end
end
