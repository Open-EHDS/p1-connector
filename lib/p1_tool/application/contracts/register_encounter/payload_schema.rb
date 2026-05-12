# frozen_string_literal: true

module P1Tool
  module Application
    module Contracts
      module RegisterEncounter
        PayloadSchema = Dry::Schema.Params do
          required(:patient).hash do
            required(:pesel).filled(:string)
            required(:first_name).filled(:string)
            required(:last_name).filled(:string)
          end

          required(:doctor).hash do
            required(:name).filled(:string)
            required(:profession_code).filled(:string)
            optional(:medical_profession_code).maybe(:string)
            optional(:npwz).maybe(:string)
            optional(:pesel).maybe(:string)
          end

          required(:encounter).hash do
            required(:start_time).filled(:string)
            required(:end_time).filled(:string)
            required(:class_code).filled(:string)
            optional(:class_name).maybe(:string)
            optional(:identifier).maybe(:string)
            optional(:episode_id).maybe(:string)
            optional(:resource_id).maybe(:string)
            optional(:status).maybe(:string)
          end

          optional(:payer).hash do
            optional(:identifier_system).maybe(:string)
            optional(:identifier_value).maybe(:string)
          end
        end
      end
    end
  end
end
