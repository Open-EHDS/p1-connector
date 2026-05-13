# frozen_string_literal: true

require 'nokogiri'

module P1Tool
  module Application
    module Builders
      module Procedure
        class XmlBuilder
          include P1Tool::Xml::BuilderHelpers
          include P1Tool::Xml::DebugSupport

          def initialize(data, constants: Constants)
            @data = data
            @constants = constants
          end

          def call
            xml = Nokogiri::XML::Builder.new(encoding: 'UTF-8') { |builder| build_procedure(builder) }.to_xml
            persist_debug_xml(xml:, resource_name: 'procedure', identifier: debug_identifier)
            xml
          end

          private

          attr_reader :data, :constants

          def build_procedure(xml)
            xml.Procedure(xmlns: 'http://hl7.org/fhir') do
              resource_id(xml, data[:resource_id])
              meta(xml)
              xml.status(value: data[:status])
              code(xml)
              subject(xml)
              encounter(xml)
              performed_period(xml)
              asserter(xml)
              location(xml)
              body_site(xml)
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

          def code(xml)
            xml.code do
              xml.coding do
                xml.system(value: constants::PROCEDURE_CODE_SYSTEM)
                xml.code(value: data[:icd_9_code])
                display(xml, data[:icd_9_name])
              end
            end
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

          def performed_period(xml)
            xml.performedPeriod do
              xml.start(value: data[:start_time])
              xml.end(value: data[:end_time])
            end
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

          def location(xml)
            xml.location do
              identifier(xml, system: data[:location_identifier_system], value: data[:location_identifier_value])
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

          def debug_identifier
            data[:resource_id] || data[:encounter_reference_id] || data[:icd_9_code]
          end
        end
      end
    end
  end
end
