# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class RegisterProcedure < RegisterResource
        private

        def operation_kind
          'register_procedure'
        end

        def resource_type
          'Procedure'
        end

        def payload_validator = P1Tool::Application::Contracts::RegisterProcedure::PayloadValidator.new

        def data_builder = P1Tool::Application::Builders::Procedure::DataBuilder

        def xml_builder = P1Tool::Application::Builders::Procedure::XmlBuilder

        def submission_class = P1Tool::Application::Integrations::P1::Procedure::Submit
      end
    end
  end
end
