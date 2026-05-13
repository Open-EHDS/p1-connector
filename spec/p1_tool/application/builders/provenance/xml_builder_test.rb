# frozen_string_literal: true

require_relative '../../../../test_helper'

describe P1Tool::Application::Builders::Provenance::XmlBuilder do
  let(:builder_class) { P1Tool::Application::Builders::Provenance::XmlBuilder }
  let(:data_builder_class) { P1Tool::Application::Builders::Provenance::DataBuilder }
  let(:validator_class) { P1Tool::Application::Contracts::RegisterProvenance::PayloadValidator }
  let(:subject) { runtime_subject_config }
  let(:validated_payload) do
    validator_class.new.validate!(
      payload: fixture_json('runtime', 'register_provenance_input.json').fetch('payload'),
      subject:
    )
  end
  let(:data) do
    data_builder_class.new(
      payload: validated_payload,
      subject:,
      signature: 'c2lnbmF0dXJl'
    ).call
  end

  describe '#call' do
    it 'matches the register_provenance XML contract fixture' do
      xml = builder_class.new(data).call

      assert_xml_equal fixture_text('xml', 'register_provenance.xml'), xml
    end

    it 'builds provenance xml with targets and signature' do
      xml = builder_class.new(data).call

      document = Nokogiri::XML(xml)

      assert_equal 'Provenance', document.root.name
      assert_equal 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLMedicalEventProvenance',
                   document.at_xpath('//*[local-name()="meta"]/*[local-name()="profile"]')['value']
      assert_equal(%w[Patient Encounter Procedure Condition],
                   document.xpath('//*[local-name()="target"]/*[local-name()="type"]').map { |node| node['value'] })
      assert_equal '2021-09-28T13:00:00+02:00',
                   document.at_xpath('//*[local-name()="recorded"]')['value']
      assert_equal 'application/signature+xml',
                   document.at_xpath('//*[local-name()="signature"]/*[local-name()="sigFormat"]')['value']
      assert_equal 'c2lnbmF0dXJl',
                   document.at_xpath('//*[local-name()="signature"]/*[local-name()="data"]')['value']
    end
  end
end
