# frozen_string_literal: true

require "dry/schema"

module P1Tool
  module Core
    ConfigurationSchema = Dry::Schema.Params do
      required(:paths).hash do
        required(:inbox).filled(:string)
        required(:processing).filled(:string)
        required(:done).filled(:string)
        required(:invalid).filled(:string)
        required(:results).filled(:string)
        required(:audit_log).filled(:string)
      end

      required(:redis).hash do
        required(:url).filled(:string)
      end

      required(:signature_service).hash do
        required(:url).filled(:string)
      end

      required(:subject).hash do
        required(:oid).filled(:string)
        required(:identification_code).filled(:string)
        required(:department_code_v).filled(:string)
        required(:department_code_vii).filled(:string)
        required(:is_practice).filled(:bool)
        required(:medical_chamber).filled(:string)
      end

      required(:certificates).hash do
        required(:base_path).filled(:string)

        required(:signing).hash do
          required(:filename).filled(:string)
          required(:password_env).filled(:string)
        end

        required(:tls).hash do
          required(:filename).filled(:string)
          required(:password_env).filled(:string)
        end
      end
    end
  end
end
