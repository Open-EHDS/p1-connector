# frozen_string_literal: true

require 'nokogiri'

module P1Tool
  module Application
    module Builders
      module Condition
        class XmlBuilder
          include P1Tool::Xml::BuilderHelpers
          include P1Tool::Xml::DebugSupport

          def initialize(data, constants: Constants)
            @data = data
            @constants = constants
          end

          def call
            xml = Nokogiri::XML::Builder.new(encoding: 'UTF-8') { |builder| build_condition(builder) }.to_xml
            persist_debug_xml(xml:, resource_name: 'condition', identifier: debug_identifier)
            xml
          end

          private

          attr_reader :data, :constants

          def build_condition(xml)
            xml.Condition(xmlns: 'http://hl7.org/fhir') do
              resource_id(xml, data[:resource_id])
              meta(xml)
              location_extension(xml)
              category(xml)
              code(xml)
              body_site(xml)
              subject(xml)
              encounter(xml)
              xml.recordedDate(value: data[:recorded_date])
              asserter(xml)
            end
          end

          def meta(xml)
            xml.meta do
              xml.profile(value: constants::PROFILE)
              xml.security { xml.system(value: constants::SECURITY_SYSTEM); xml.code(value: constants::DEFAULT_SECURITY_CODE) }
            end
          end

          def location_extension(xml)
            xml.extension(url: constants::LOCATION_EXTENSION) do
              xml.valueIdentifier do
                xml.system(value: data[:location_identifier_system])
                xml.value(value: data[:location_identifier_value])
              end
            end
          end

          def category(xml)
            xml.category do
              xml.coding do
                xml.system(value: constants::CONDITION_CATEGORY_SYSTEM)
                xml.code(value: data[:category_code])
                display(xml, data[:category_display])
              end
            end
          end

          def code(xml)
            xml.code do
              xml.coding do
                xml.system(value: constants::ICD_10_CODE_SYSTEM)
                xml.code(value: data[:icd_10_code])
                display(xml, data[:icd_10_name])
              end
            end
          end

          def body_site(xml)
            return if blank?(data[:element_code])

            xml.bodySite do
              xml.coding do
                xml.system(value: data[:element_system])
                xml.code(value: data[:element_code])
                display(xml, data[:element_display])
              end
            end
          end

          def subject(xml)
            xml.subject do
              xml.reference(value: "Patient/#{data[:patient_reference_id]}")
              xml.type(value: 'Patient')
              identifier(xml, system: constants.patient_pesel_system, value: data[:patient_pesel])
            end
          end

          def encounter(xml)
            xml.encounter do
              xml.reference(value: "Encounter/#{data[:encounter_reference_id]}")
              xml.type(value: 'Encounter')
            end
          end

          def asserter(xml)
            xml.asserter do
              xml.extension(url: constants::PL_FUNCTION_EXTENSION) do
                xml.valueCoding do
                  xml.system(value: constants::DOCTOR_PROFESSION_SYSTEM)
                  xml.code(value: data[:doctor_profession_number])
                end
              end
              identifier(xml, system: data[:doctor_identifier_system], value: data[:doctor_identifier_value])
              display(xml, data[:doctor_name])
            end
          end

          def debug_identifier
            data[:resource_id] || data[:encounter_reference_id] || data[:icd_10_code]
          end
        end
      end
    end
  end
end
