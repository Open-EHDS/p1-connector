# frozen_string_literal: true

require 'nokogiri'
require_relative '../../../../test_helper'

describe P1Tool::Application::Builders::Encounter::XmlBuilder do
  let(:builder_class) { P1Tool::Application::Builders::Encounter::XmlBuilder }
  let(:data_builder_class) { P1Tool::Application::Builders::Encounter::DataBuilder }
  let(:validator_class) { P1Tool::Application::Contracts::RegisterEncounter::PayloadValidator }
  let(:payload) do
    validator_class.new.validate!(
      payload: fixture_json('runtime', 'register_encounter_input.json').fetch('payload'),
      subject: runtime_subject_config
    )
  end
  let(:subject) { runtime_subject_config }
  let(:id_generator) do
    identifiers = %w[encounter-identifier-1 episode-identifier-1].each
    -> { identifiers.next }
  end
  let(:data) do
    data_builder_class.new(
      payload:,
      subject:,
      id_generator:
    ).call.merge(
      patient_reference_id: 'stub-patient-75061134485'
    )
  end

  describe '#call' do
    it 'matches the register_encounter XML contract fixture' do
      xml = builder_class.new(data).call

      assert_xml_equal fixture_text('xml', 'register_encounter.xml'), xml
    end

    it 'builds encounter XML for entity subject config' do
      xml = builder_class.new(data).call
      document = Nokogiri::XML(xml)

      assert_equal 'Encounter', document.root.name
      assert_equal(
        'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLMedicalEvent',
        document.at_xpath('//*[local-name()="profile"]')[:value]
      )
      assert_equal(
        'urn:oid:2.16.840.1.113883.3.4424.11.1.34',
        document.at_xpath('//*[local-name()="class"]/*[local-name()="system"]')[:value]
      )
      assert_equal '4', document.at_xpath('//*[local-name()="class"]/*[local-name()="code"]')[:value]
      assert_equal(
        'Patient/stub-patient-75061134485',
        document.at_xpath('//*[local-name()="subject"]/*[local-name()="reference"]')[:value]
      )
      assert_equal(
        'urn:oid:2.16.840.1.113883.3.4424.2.3.3',
        value_at(
          document,
          '//*[local-name()="location"]/*[local-name()="location"]/*' \
          '[local-name()="identifier"]/*[local-name()="system"]'
        )
      )
      assert_equal(
        '1234567890-1234567',
        value_at(
          document,
          '//*[local-name()="location"]/*[local-name()="location"]/*[local-name()="identifier"]/*[local-name()="value"]'
        )
      )
      assert_equal(
        'urn:oid:2.16.840.1.113883.3.4424.2.3.1',
        value_at(
          document,
          '//*[local-name()="serviceProvider"]/*[local-name()="identifier"]/*[local-name()="system"]'
        )
      )
    end

    it 'writes debug XML to disk when enabled by environment variable' do
      Dir.mktmpdir do |tmpdir|
        ENV['P1_DEBUG_XML'] = '1'
        ENV['P1_DEBUG_XML_PATH'] = tmpdir

        xml = builder_class.new(data).call
        files = Dir.glob(File.join(tmpdir, '*.xml'))

        assert_equal 1, files.size
        assert_equal xml, File.read(files.first)
      end
    ensure
      ENV.delete('P1_DEBUG_XML')
      ENV.delete('P1_DEBUG_XML_PATH')
    end
  end

  def value_at(document, xpath)
    document.at_xpath(xpath)[:value]
  end
end
