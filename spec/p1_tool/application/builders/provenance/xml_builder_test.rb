# frozen_string_literal: true

require_relative '../../../../test_helper'

describe P1Tool::Application::Builders::Provenance::XmlBuilder do
  let(:builder_class) { P1Tool::Application::Builders::Provenance::XmlBuilder }

  describe '#call' do
    it 'builds provenance xml with targets and signature' do
      xml = builder_class.new(
        {
          recorded_at: '2021-09-28T13:00:00+02:00',
          targets: [
            { resource_type: 'Patient', reference_id: 'pat-123', version_id: '7' },
            { resource_type: 'Encounter', reference_id: 'enc-123', version_id: '1' },
            { resource_type: 'Procedure', reference_id: 'proc-123', version_id: '1' }
          ],
          provider_identifier_system: 'urn:oid:2.16.840.1.113883.3.4424.2.3.1',
          provider_identifier_value: '000000927154',
          signature: 'c2lnbmF0dXJl'
        }
      ).call

      document = Nokogiri::XML(xml)

      assert_equal 'Provenance', document.root.name
      assert_equal 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLMedicalEventProvenance',
                   document.at_xpath('//*[local-name()="meta"]/*[local-name()="profile"]')['value']
      assert_equal %w[Patient Encounter Procedure],
                   document.xpath('//*[local-name()="target"]/*[local-name()="type"]').map { |node| node['value'] }
      assert_equal '2021-09-28T13:00:00+02:00',
                   document.at_xpath('//*[local-name()="recorded"]')['value']
      assert_equal 'application/signature+xml',
                   document.at_xpath('//*[local-name()="signature"]/*[local-name()="sigFormat"]')['value']
      assert_equal 'c2lnbmF0dXJl',
                   document.at_xpath('//*[local-name()="signature"]/*[local-name()="data"]')['value']
    end
  end
end
