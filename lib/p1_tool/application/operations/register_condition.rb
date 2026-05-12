# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class RegisterCondition < RegisterResource
        private

        def operation_kind
          'register_condition'
        end

        def resource_type
          'Condition'
        end

        def payload_validator = P1Tool::Application::Contracts::RegisterCondition::PayloadValidator.new

        def data_builder = P1Tool::Application::Builders::Condition::DataBuilder

        def xml_builder = P1Tool::Application::Builders::Condition::XmlBuilder

        def submission_class = P1Tool::Application::Integrations::P1::Condition::Submit
      end
    end
  end
end
