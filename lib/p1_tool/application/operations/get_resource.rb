# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      class GetResource
        def self.call(input, config: nil, p1_client: nil)
          new(input, config:, p1_client:).call
        end

        def initialize(input, config:, p1_client: nil)
          @delegate = GetResourceOperation.new(
            input,
            config:,
            p1_client:
          )
        end

        def call
          @delegate.call
        end
      end
    end
  end
end
