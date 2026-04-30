# frozen_string_literal: true

require_relative "../../test_helper"

class P1ToolInputValidatorTest < Minitest::Test
  def test_validate_returns_normalized_input_for_supported_operation_kind
    input = {
      "task_id" => "task-1",
      "operation_kind" => "hello_world",
      "payload" => { "name" => "Alice" },
      "options" => { "attempt" => 1 }
    }

    result = P1Tool::Core::InputValidator.validate(
      input,
      operation_kinds: P1Tool::Application::Dispatcher.supported_operation_kinds
    )

    assert_equal "task-1", result[:task_id]
    assert_equal "hello_world", result[:operation_kind]
    assert_equal({ name: "Alice" }, result[:payload])
    assert_equal({ attempt: 1 }, result[:options])
  end

  def test_validate_rejects_unknown_operation_kind
    error = assert_raises(P1Tool::InputValidationError) do
      P1Tool::Core::InputValidator.validate(
        valid_input.merge("operation_kind" => "unknown"),
        operation_kinds: P1Tool::Application::Dispatcher.supported_operation_kinds
      )
    end

    assert_equal ["must be one of: hello_world"], error.details[:operation_kind]
  end

  def test_validate_rejects_missing_required_keys
    error = assert_raises(P1Tool::InputValidationError) do
      P1Tool::Core::InputValidator.validate(
        { "operation_kind" => "hello_world", "payload" => {} },
        operation_kinds: P1Tool::Application::Dispatcher.supported_operation_kinds
      )
    end

    assert_equal ["is missing"], error.details[:task_id]
  end

  private

  def valid_input
    {
      "task_id" => "task-1",
      "operation_kind" => "hello_world",
      "payload" => { "name" => "Alice" }
    }
  end
end
