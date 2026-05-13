# frozen_string_literal: true

require 'nokogiri'

module P1Tool
  module Application
    module Builders
      module Encounter
        class XmlBuilder
          include P1Tool::Xml::BuilderHelpers
          include P1Tool::Xml::DebugSupport
          include XmlSectionHelpers

          def initialize(data, constants: Constants)
            @data = data
            @constants = constants
          end

          def call
            xml = Nokogiri::XML::Builder.new(encoding: 'UTF-8') { |builder| build_encounter(builder) }.to_xml
            persist_debug_xml(xml:, resource_name: 'encounter', identifier: data[:encounter_identifier])
            xml
          end

          private

          attr_reader :data, :constants

          def build_encounter(xml)
            xml.Encounter(xmlns: 'http://hl7.org/fhir') do
              encounter_identity(xml)
              encounter_details(xml)
            end
          end

          def encounter_identity(xml)
            resource_id(xml, data[:resource_id])
            meta(xml)
            identifier(xml, system: data[:encounter_identifier_system], value: data[:encounter_identifier])
            xml.status(value: data[:status])
          end

          def encounter_details(xml)
            encounter_class(xml)
            subject(xml)
            episode_of_care(xml)
            participant(xml)
            period(xml)
            location(xml)
            service_provider(xml)
          end
        end
      end
    end
  end
end
