# frozen_string_literal: true

require 'dry/schema'

module P1Tool
  module Core
    InputSchema = Dry::Schema.Params do
      required(:task_id).filled(:string)
      required(:operation_kind).filled(:string)
      required(:payload).hash
      optional(:options).hash
    end
  end
end
