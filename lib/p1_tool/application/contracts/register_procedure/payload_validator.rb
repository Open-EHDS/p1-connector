# frozen_string_literal: true

module P1Tool
  module Application
    module Contracts
      module RegisterProcedure
        class PayloadValidator < BaseRegistrationPayloadValidator
          def initialize(
            constants: P1Tool::Application::Builders::Procedure::Constants,
            element_catalog: P1Tool::Application::ReferenceData::P1ElementCatalog.new
          )
            super(constants:)
            @element_catalog = element_catalog
          end

          private

          attr_reader :element_catalog

          def apply_business_rules(validation:, normalized:, details:)
            normalized_payload = normalized_payload(validation, normalized)
            super
            validate_period!(normalized_payload, details, section: :procedure)
            validate_element_code!(normalized_payload, details, section: :procedure, element_catalog:)
          end

          def payload_schema = PayloadSchema

          def medical_profession_code_required? = true

          def validation_error_message = 'Register procedure payload validation failed'

          def practice_xml_name = 'procedure'
        end
      end
    end
  end
end
