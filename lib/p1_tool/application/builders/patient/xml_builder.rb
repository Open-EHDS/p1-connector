# frozen_string_literal: true

require 'nokogiri'

module P1Tool
  module Application
    module Builders
      module Patient
        class XmlBuilder
          def initialize(payload:)
            @payload = payload
          end

          def call
            Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
              xml.Patient(xmlns: 'http://hl7.org/fhir') do
                xml.meta do
                  xml.profile(value: 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLPatient')
                end
                xml.identifier do
                  xml.system(value: P1Tool::Gateways::P1::Constants::PESEL_SYSTEM)
                  xml.value(value: patient.fetch(:pesel))
                end
                xml.name do
                  xml.family(value: patient.fetch(:last_name))
                  patient.fetch(:first_name).to_s.split.each { |name| xml.given(value: name) }
                end
              end
            end.to_xml
          end

          private

          attr_reader :payload

          def patient
            payload.fetch(:patient)
          end
        end
      end
    end
  end
end
