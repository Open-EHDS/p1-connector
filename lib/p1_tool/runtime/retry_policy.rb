# frozen_string_literal: true

module P1Tool
  module Runtime
    module RetryPolicy
      MAX_ATTEMPTS = 2
      RETRYABLE_CATEGORIES = %w[technical transient].freeze

      module_function

      def category_for(error)
        case error
        when P1Tool::TransientError
          'transient'
        when P1Tool::BusinessError
          'business'
        else
          'technical'
        end
      end

      def retryable?(error_or_category)
        category = error_or_category.is_a?(String) ? error_or_category : category_for(error_or_category)
        RETRYABLE_CATEGORIES.include?(category)
      end

      def exhausted?(attempt)
        attempt >= MAX_ATTEMPTS
      end
    end
  end
end
