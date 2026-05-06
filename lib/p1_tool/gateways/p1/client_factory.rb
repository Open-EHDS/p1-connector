# frozen_string_literal: true

module P1Tool
  module Gateways
    module P1
      class ClientFactory
        def self.build(config:, doctor:)
          new(config:, doctor:).build
        end

        def initialize(config:, doctor:)
          @config = config
          @doctor = doctor
        end

        def build
          Client.new(config:, subject: config.fetch(:subject), doctor:)
        end

        private

        attr_reader :config, :doctor
      end
    end
  end
end
