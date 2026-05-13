# frozen_string_literal: true

require 'securerandom'
require 'time'

module P1Tool
  module Runtime
    module RuntimeEnvironment
      class << self
        def bootstrap!(
          config:,
          workspace: nil,
          audit_log: nil,
          dependencies: {}
        )
          file_system = dependencies.fetch(:file_system, P1Tool::Adapters::FileSystem.new)
          clock = dependencies.fetch(:clock, -> { Time.now.utc })
          transport_id_generator = dependencies.fetch(:transport_id_generator, -> { SecureRandom.uuid })

          workspace ||= P1Tool::Runtime::Workspace.new(config, file_system: file_system)
          workspace.prepare!

          audit_log ||= P1Tool::Adapters::AuditLog.new(
            config.dig(:paths, :audit_log),
            file_system: file_system,
            clock: clock
          )

          @state = {
            config: config,
            workspace: workspace,
            file_system: file_system,
            audit_log: audit_log,
            clock: clock,
            transport_id_generator: transport_id_generator
          }
        end

        def config
          fetch(:config)
        end

        def workspace
          fetch(:workspace)
        end

        def audit_log
          fetch(:audit_log)
        end

        def file_system
          fetch(:file_system)
        end

        def clock
          fetch(:clock)
        end

        def transport_id_generator
          fetch(:transport_id_generator)
        end

        def reset!
          @state = nil
        end

        private

        def fetch(key)
          raise P1Tool::RuntimeNotBootstrappedError, 'Runtime environment is not bootstrapped' if @state.nil?

          @state.fetch(key)
        end
      end
    end
  end
end
