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
            fhir_meta(
              xml,
              profile: constants::PROFILE,
              security_system: constants::SECURITY_SYSTEM,
              security_code: constants::DEFAULT_SECURITY_CODE
            )
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
            fhir_body_site(
              xml,
              code: data[:element_code],
              system: data[:element_system],
              display_value: data[:element_display]
            )
          end

          def subject(xml)
            patient_subject(
              xml,
              reference_id: data[:patient_reference_id],
              pesel_system: constants.patient_pesel_system,
              pesel: data[:patient_pesel]
            )
          end

          def encounter(xml)
            encounter_reference(xml, reference_id: data[:encounter_reference_id])
          end

          def asserter(xml)
            xml.asserter do
              doctor_function_extension(
                xml,
                profession_number: data[:doctor_profession_number],
                extension_url: constants::PL_FUNCTION_EXTENSION,
                profession_system: constants::DOCTOR_PROFESSION_SYSTEM
              )
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
