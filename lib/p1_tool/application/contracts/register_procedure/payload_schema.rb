# frozen_string_literal: true

module P1Tool
  module Application
    module Contracts
      module RegisterProcedure
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
            required(:resource_id).filled(:string)
          end

          required(:procedure).hash do
            required(:icd_9_code).filled(:string)
            required(:icd_9_name).filled(:string)
            required(:start_time).filled(:string)
            required(:end_time).filled(:string)
            optional(:element_code).maybe(:string)
            optional(:resource_id).maybe(:string)
            optional(:status).maybe(:string)
          end
        end
      end
    end
  end
end
