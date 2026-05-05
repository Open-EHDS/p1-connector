# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class HelloWorld
        def self.call(input)
          new(input).call
        end

        def initialize(input)
          @input = input
        end

        def call
          {
            message: 'hello world',
            task_id: @input.fetch(:task_id),
            operation_kind: @input.fetch(:operation_kind),
            payload: @input.fetch(:payload)
          }
        end
      end
    end
  end
end
