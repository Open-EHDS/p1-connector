# frozen_string_literal: true

module P1Tool
  class Error < StandardError; end

  class RuntimeNotBootstrappedError < Error; end

  class InputValidationError < Error
    attr_reader :details

    def initialize(message, details: nil)
      @details = details
      super(message)
    end
  end

  class ConfigurationError < Error
    attr_reader :details

    def initialize(message, details: nil)
      @details = details
      super(message)
    end
  end

  class BusinessError < Error; end
  class TransientError < Error; end
end
