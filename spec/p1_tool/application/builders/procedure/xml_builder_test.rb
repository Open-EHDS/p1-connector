# frozen_string_literal: true

require_relative '../../../../test_helper'

describe P1Tool::Application::Builders::Procedure::XmlBuilder do
  let(:builder_class) { P1Tool::Application::Builders::Procedure::XmlBuilder }

  describe '#call' do
    it 'builds procedure xml with bodySite when element is present' do
      xml = builder_class.new(
        {
          resource_id: 'proc-123',
          status: 'completed',
          icd_9_code: '23.1108',
          icd_9_name: 'Wypelnienie ubytku korony zeba mlecznego',
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
          start_time: '2021-09-28T12:30:00+02:00',
          end_time: '2021-09-28T13:00:00+02:00'
        }
      ).call

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
      xml = builder_class.new(
        {
          status: 'completed',
          icd_9_code: '23.0105',
          icd_9_name: 'Konsultacja specjalistyczna',
          encounter_reference_id: 'enc-123',
          patient_reference_id: 'pat-123',
          patient_pesel: '75061134485',
          doctor_name: 'Adam739 Leczniczy',
          doctor_identifier_system: 'urn:oid:2.16.840.1.113883.3.4424.1.6.2',
          doctor_identifier_value: '5691489',
          doctor_profession_number: '11',
          location_identifier_system: 'urn:oid:2.16.840.1.113883.3.4424.2.4.68.1',
          location_identifier_value: '000000927154',
          start_time: '2021-09-28T12:30:00+02:00',
          end_time: '2021-09-28T13:00:00+02:00'
        }
      ).call

      document = Nokogiri::XML(xml)

      assert_nil document.at_xpath('//*[local-name()="bodySite"]')
    end
  end

  def value_at(document, xpath)
    document.at_xpath(xpath)['value']
  end
end
