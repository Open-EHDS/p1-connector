# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module Provenance
        class Constants
          include P1Tool::Application::Builders::SharedConstants

          PROFILE = 'https://ezdrowie.gov.pl/fhir/StructureDefinition/PLMedicalEventProvenance'
          SIGNATURE_TYPE_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.11.1.86'
          SIGNATURE_TYPE_CODE = '1.2.840.10065.1.12.1.14'
          TARGET_FORMAT = 'application/fhir+xml'
          SIGNATURE_FORMAT = 'application/signature+xml'
        end
      end
    end
  end
end
