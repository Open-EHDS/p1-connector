# frozen_string_literal: true

require_relative '../../../../test_helper'

describe P1Tool::Application::Builders::Procedure::XmlBuilder do
  let(:builder_class) { P1Tool::Application::Builders::Procedure::XmlBuilder }
  let(:data_builder_class) { P1Tool::Application::Builders::Procedure::DataBuilder }
  let(:validator_class) { P1Tool::Application::Contracts::RegisterProcedure::PayloadValidator }
  let(:subject) { runtime_subject_config }
  let(:validated_payload) do
    validator_class.new.validate!(
      payload: fixture_json('runtime', 'register_procedure_input.json').fetch('payload'),
      subject:
    )
  end
  let(:data) do
    data_builder_class.new(
      payload: validated_payload,
      subject:
    ).call.merge(
      patient_reference_id: 'pat-123'
    )
  end

  describe '#call' do
    it 'matches the register_procedure XML contract fixture' do
      xml = builder_class.new(data).call

      assert_xml_equal fixture_text('xml', 'register_procedure.xml'), xml
    end

    it 'builds procedure xml with bodySite when element is present' do
      xml = builder_class.new(data).call

      document = Nokogiri::XML(xml)

      assert_equal 'Procedure', document.root.name
      assert_equal 'enc-123',
                   value_at(document, '//*[local-name()="encounter"]/*[local-name()="reference"]').sub(
                     'Encounter/', ''
                   )
      assert_equal '85',
                   value_at(document, '//*[local-name()="bodySite"]/*[local-name()="coding"]/*[local-name()="code"]')
      assert_equal 'dolne prawe drugie trzonowce mleczne',
                   value_at(document, '//*[local-name()="bodySite"]/*[local-name()="coding"]/*[local-name()="display"]')
    end

    it 'omits bodySite when element_code is missing' do
      xml = builder_class.new(data.merge(element_code: nil, element_system: nil, element_display: nil)).call

      document = Nokogiri::XML(xml)

      assert_nil document.at_xpath('//*[local-name()="bodySite"]')
    end
  end

  def value_at(document, xpath)
    document.at_xpath(xpath)['value']
  end
end
