# frozen_string_literal: true

require_relative "../../test_helper"

class P1ToolExecutionContextTest < Minitest::Test
  def test_to_h_returns_shared_task_attributes
    context = P1Tool::Runtime::ExecutionContext.new(
      transport_id: "transport-1",
      task_id: "task-1",
      operation_kind: "hello_world",
      attempt: 1,
      correlation_id: "corr-1",
      config_version: "cfg-v1",
      runtime_mode: "run_once",
      source_path: "/data/processing/task-1.json"
    )

    assert_equal(
      {
        transport_id: "transport-1",
        task_id: "task-1",
        operation_kind: "hello_world",
        attempt: 1,
        correlation_id: "corr-1",
        config_version: "cfg-v1",
        runtime_mode: "run_once",
        source_path: "/data/processing/task-1.json"
      },
      context.to_h
    )
  end

  def test_to_h_skips_optional_nil_attributes
    context = P1Tool::Runtime::ExecutionContext.new(
      transport_id: "transport-1",
      task_id: "task-1",
      operation_kind: "hello_world",
      attempt: 1,
      correlation_id: "corr-1"
    )

    assert_equal(
      {
        transport_id: "transport-1",
        task_id: "task-1",
        operation_kind: "hello_world",
        attempt: 1,
        correlation_id: "corr-1"
      },
      context.to_h
    )
  end

  def test_with_returns_new_context_with_overridden_attributes
    context = P1Tool::Runtime::ExecutionContext.new(
      transport_id: "transport-1",
      task_id: nil,
      operation_kind: nil,
      attempt: 1,
      correlation_id: "corr-1"
    )

    updated_context = context.with(task_id: "task-1", operation_kind: "hello_world")

    assert_nil context.task_id
    assert_nil context.operation_kind
    assert_equal "task-1", updated_context.task_id
    assert_equal "hello_world", updated_context.operation_kind
    assert_equal "transport-1", updated_context.transport_id
  end
end
