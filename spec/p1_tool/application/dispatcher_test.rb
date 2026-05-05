# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Application::Dispatcher do
  describe '.call' do
    it 'invokes hello_world operation' do
      result = P1Tool::Application::Dispatcher.call(
        task_id: 'task-1',
        operation_kind: 'hello_world',
        payload: { name: 'Alice' }
      )

      assert_equal 'hello world', result[:message]
      assert_equal 'task-1', result[:task_id]
      assert_equal 'hello_world', result[:operation_kind]
      assert_equal({ name: 'Alice' }, result[:payload])
    end

    it 'rejects unsupported operation_kind' do
      error = assert_raises(P1Tool::InputValidationError) do
        P1Tool::Application::Dispatcher.call(
          task_id: 'task-1',
          operation_kind: 'not_supported',
          payload: {}
        )
      end

      assert_equal ['must be one of: hello_world'], error.details[:operation_kind]
    end
  end
end
