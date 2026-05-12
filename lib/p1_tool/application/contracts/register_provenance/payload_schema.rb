# frozen_string_literal: true

module P1Tool
  module Application
    module Contracts
      module RegisterProvenance
        PayloadSchema = Dry::Schema.Params do
          required(:doctor).hash do
            required(:name).filled(:string)
            required(:profession_code).filled(:string)
            optional(:medical_profession_code).maybe(:string)
            optional(:npwz).maybe(:string)
            optional(:pesel).maybe(:string)
          end

          required(:references).array(:hash) do
            required(:resource_type).filled(:string)
            required(:reference_id).filled(:string)
            required(:version_id).filled(:string)
          end

          required(:provenance).hash do
            required(:recorded_at).filled(:string)
            optional(:resource_id).maybe(:string)
          end
        end
      end
    end
  end
end
