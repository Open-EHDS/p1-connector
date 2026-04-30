# frozen_string_literal: true

module P1Tool
  class Error < StandardError; end

  class ConfigurationError < Error
    attr_reader :details

    def initialize(message, details: nil)
      @details = details
      super(message)
    end
  end
end
