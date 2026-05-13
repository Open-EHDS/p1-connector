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
            xml.meta do
              xml.profile(value: constants::PROFILE)
              xml.security do
                xml.system(value: constants::SECURITY_SYSTEM)
                xml.code(value: constants::DEFAULT_SECURITY_CODE)
              end
            end
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

          def performed_period(xml)
            xml.performedPeriod do
              xml.start(value: data[:start_time])
              xml.end(value: data[:end_time])
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

          def location(xml)
            xml.location do
              identifier(xml, system: data[:location_identifier_system], value: data[:location_identifier_value])
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

          def debug_identifier
            data[:resource_id] || data[:encounter_reference_id] || data[:icd_9_code]
          end
        end
      end
    end
  end
end
