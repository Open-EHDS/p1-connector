# frozen_string_literal: true

require 'json'
require 'time'

module P1Tool
  module Adapters
    class AuditLog
      def initialize(path, file_system: P1Tool::Adapters::FileSystem.new, clock: -> { Time.now.utc })
        @path = path
        @file_system = file_system
        @clock = clock
      end

      def record_start(context, metadata: nil)
        append_event(
          context,
          event_type: 'execution_started',
          result: 'started',
          metadata: metadata
        )
      end

      def record_finish(context, result:, metadata: nil)
        append_event(
          context,
          event_type: 'execution_finished',
          result: result,
          metadata: metadata
        )
      end

      def record_error(context, error_code:, error_category:, metadata: nil, result: 'error')
        append_event(
          context,
          event_type: 'execution_error',
          result: result,
          error_code: error_code,
          error_category: error_category,
          metadata: metadata
        )
      end

      def record_event(context, event_type:, metadata: nil, result: nil)
        append_event(
          context,
          event_type: event_type,
          result: result,
          metadata: metadata
        )
      end

      private

      def append_event(context, **attributes)
        entry = { timestamp: @clock.call.iso8601 }
                .merge(context.to_h)
                .merge(compact_hash(attributes))

        @file_system.mkdir_p(File.dirname(@path))

        File.open(@path, 'a') do |file|
          file.puts(JSON.generate(entry))
        end

        entry
      end

      def compact_hash(hash)
        hash.each_with_object({}) do |(key, value), result|
          result[key] = value unless value.nil?
        end
      end
    end
  end
end
