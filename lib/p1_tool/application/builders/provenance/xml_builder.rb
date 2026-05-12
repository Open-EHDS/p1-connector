# frozen_string_literal: true

require 'nokogiri'

module P1Tool
  module Application
    module Builders
      module Provenance
        class XmlBuilder
          include P1Tool::Xml::BuilderHelpers
          include P1Tool::Xml::DebugSupport

          def initialize(data, constants: Constants)
            @data = data
            @constants = constants
          end

          def call
            xml = Nokogiri::XML::Builder.new(encoding: 'UTF-8') { |builder| build_provenance(builder) }.to_xml
            persist_debug_xml(xml:, resource_name: 'provenance', identifier: debug_identifier)
            xml
          end

          private

          attr_reader :data, :constants

          def build_provenance(xml)
            xml.Provenance(xmlns: 'http://hl7.org/fhir') do
              resource_id(xml, data[:resource_id])
              meta(xml)
              targets(xml)
              xml.recorded(value: data[:recorded_at])
              agent(xml)
              signature(xml)
            end
          end

          def meta(xml)
            xml.meta do
              xml.profile(value: constants::PROFILE)
              xml.security { xml.system(value: constants::SECURITY_SYSTEM); xml.code(value: constants::DEFAULT_SECURITY_CODE) }
            end
          end

          def targets(xml)
            data.fetch(:targets).each do |target|
              xml.target do
                xml.reference(value: "#{target.fetch(:resource_type)}/#{target.fetch(:reference_id)}")
                xml.type(value: target.fetch(:resource_type))
              end
            end
          end

          def agent(xml)
            xml.agent do
              xml.who do
                identifier(xml, system: data[:provider_identifier_system], value: data[:provider_identifier_value])
              end
            end
          end

          def signature(xml)
            xml.signature do
              xml.type do
                xml.system(value: constants::SIGNATURE_TYPE_SYSTEM)
                xml.code(value: constants::SIGNATURE_TYPE_CODE)
              end
              xml.when(value: data[:recorded_at])
              xml.who do
                identifier(xml, system: data[:provider_identifier_system], value: data[:provider_identifier_value])
              end
              xml.targetFormat(value: constants::TARGET_FORMAT)
              xml.sigFormat(value: constants::SIGNATURE_FORMAT)
              xml.data(value: data[:signature])
            end
          end

          def debug_identifier
            data[:resource_id] || data.fetch(:targets).map { |target| target.fetch(:reference_id) }.join('_')
          end
        end
      end
    end
  end
end
