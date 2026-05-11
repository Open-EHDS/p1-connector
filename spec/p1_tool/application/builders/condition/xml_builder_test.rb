# frozen_string_literal: true

require_relative '../../../../test_helper'

describe P1Tool::Application::Builders::Condition::XmlBuilder do
  let(:builder_class) { P1Tool::Application::Builders::Condition::XmlBuilder }

  describe '#call' do
    it 'builds condition xml with location extension and bodySite' do
      xml = builder_class.new(
        {
          resource_id: 'cond-123',
          icd_10_code: 'K02',
          icd_10_name: 'Prochnica zebow',
          encounter_reference_id: 'enc-123',
          patient_reference_id: 'pat-123',
          patient_pesel: '75061134485',
          doctor_name: 'Adam739 Leczniczy',
          doctor_identifier_system: 'urn:oid:2.16.840.1.113883.3.4424.1.6.2',
          doctor_identifier_value: '5691489',
          doctor_profession_number: '11',
          location_identifier_system: 'urn:oid:2.16.840.1.113883.3.4424.2.4.68.1',
          location_identifier_value: '000000927154',
          element_code: '85',
          element_system: 'urn:oid:2.16.840.1.113883.3.4424.11.1.123',
          element_display: 'dolne prawe drugie trzonowce mleczne',
          recorded_date: '2021-09-28T12:30:00+02:00'
        }
      ).call

      document = Nokogiri::XML(xml)

      assert_equal 'Condition', document.root.name
      assert_equal 'enc-123', document.at_xpath('//*[local-name()="encounter"]/*[local-name()="reference"]')['value'].sub('Encounter/', '')
      assert_equal '000000927154',
                   document.at_xpath('//*[local-name()="extension"]/*[local-name()="valueIdentifier"]/*[local-name()="value"]')['value']
      assert_equal '85', document.at_xpath('//*[local-name()="bodySite"]/*[local-name()="coding"]/*[local-name()="code"]')['value']
    end

    it 'omits bodySite when element_code is missing' do
      xml = builder_class.new(
        {
          icd_10_code: 'K02',
          icd_10_name: 'Prochnica zebow',
          encounter_reference_id: 'enc-123',
          patient_reference_id: 'pat-123',
          patient_pesel: '75061134485',
          doctor_name: 'Adam739 Leczniczy',
          doctor_identifier_system: 'urn:oid:2.16.840.1.113883.3.4424.1.6.2',
          doctor_identifier_value: '5691489',
          doctor_profession_number: '11',
          location_identifier_system: 'urn:oid:2.16.840.1.113883.3.4424.2.4.68.1',
          location_identifier_value: '000000927154',
          recorded_date: '2021-09-28T12:30:00+02:00'
        }
      ).call

      document = Nokogiri::XML(xml)

      assert_nil document.at_xpath('//*[local-name()="bodySite"]')
    end
  end
end
