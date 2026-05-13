# frozen_string_literal: true

module P1Tool
  module Xml
    module BuilderHelpers
      private

      def resource_id(xml, value)
        return if blank?(value)

        xml.id(value:)
      end

      def identifier(xml, system:, value:)
        xml.identifier do
          xml.system(value: system)
          xml.value(value:)
        end
      end

      def fhir_meta(xml, profile:, security_system:, security_code:)
        xml.meta do
          xml.profile(value: profile)
          xml.security do
            xml.system(value: security_system)
            xml.code(value: security_code)
          end
        end
      end

      def patient_subject(xml, reference_id:, pesel_system:, pesel:, display_name: nil)
        xml.subject do
          xml.reference(value: "Patient/#{reference_id}")
          xml.type(value: 'Patient')
          identifier(xml, system: pesel_system, value: pesel)
          display(xml, display_name) unless blank?(display_name)
        end
      end

      def encounter_reference(xml, reference_id:)
        xml.encounter do
          xml.reference(value: "Encounter/#{reference_id}")
          xml.type(value: 'Encounter')
        end
      end

      def doctor_function_extension(xml, profession_number:, extension_url:, profession_system:)
        xml.extension(url: extension_url) do
          xml.valueCoding do
            xml.system(value: profession_system)
            xml.code(value: profession_number)
          end
        end
      end

      def fhir_body_site(xml, code:, system:, display_value:)
        return if blank?(code)

        xml.bodySite do
          xml.coding do
            xml.system(value: system)
            xml.code(value: code)
            display(xml, display_value)
          end
        end
      end

      def display(xml, value)
        node = Nokogiri::XML::Node.new('display', xml.doc)
        node['value'] = value
        xml.parent.add_child(node)
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end
    end
  end
end
