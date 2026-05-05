# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-cron'

module P1Tool
  module Runtime
    class ContinuousRunner
      DEFAULT_SIDEKIQ_CONFIG_PATH = File.expand_path('../../../config/sidekiq.yml', __dir__)
      DEFAULT_SIDEKIQ_CRON_CONFIG_PATH = File.expand_path('../../../config/sidekiq-cron.yml', __dir__)

      def initialize(
        config_path:,
        sidekiq_config_path: DEFAULT_SIDEKIQ_CONFIG_PATH,
        sidekiq_cron_config_path: DEFAULT_SIDEKIQ_CRON_CONFIG_PATH,
        stdout: $stdout
      )
        @config_path = File.expand_path(config_path)
        @sidekiq_config_path = File.expand_path(sidekiq_config_path)
        @sidekiq_cron_config_path = File.expand_path(sidekiq_cron_config_path)
        @stdout = stdout
      end

      def run
        app_config, sidekiq_config, cron_schedule = load_configs

        P1Tool::Runtime::RuntimeEnvironment.bootstrap!(config: app_config)
        recovered_files = run_recovery

        embedded = build_embedded_instance(app_config, sidekiq_config, cron_schedule)

        install_signal_handlers(embedded)

        embedded.run
        print_summary(app_config, sidekiq_config, recovered_files)
        sleep
      ensure
        embedded&.stop
      end

      private

      def load_configs
        [
          P1Tool::Core::ConfigurationLoader.load(@config_path),
          P1Tool::Runtime::SidekiqConfigLoader.load(@sidekiq_config_path),
          P1Tool::Runtime::SidekiqConfigLoader.load(@sidekiq_cron_config_path)
        ]
      end

      def build_embedded_instance(app_config, sidekiq_config, cron_schedule)
        Sidekiq.configure_embed do |config|
          apply_sidekiq_config(config, sidekiq_config, redis_url: app_config.dig(:redis, :url))
          config.server_middleware do |chain|
            chain.add(P1Tool::Jobs::JobContextMiddleware)
          end
          config.on(:startup) do
            Sidekiq::Cron::Job.load_from_hash!(cron_schedule, source: 'schedule')
          end
        end
      end

      def run_recovery
        P1Tool::Runtime::ProcessingRecovery.new(P1Tool::Runtime::RuntimeEnvironment.workspace).call
      end

      def apply_sidekiq_config(config, sidekiq_config, redis_url:)
        config.redis = { url: redis_url }
        config.concurrency = sidekiq_config.fetch('concurrency', 5)
        config.queues = Array(sidekiq_config.fetch('queues', ['continuous']))

        poll_interval = sidekiq_config['average_scheduled_poll_interval']
        config.average_scheduled_poll_interval = poll_interval if poll_interval
      end

      def install_signal_handlers(embedded)
        %w[INT TERM].each do |signal|
          Signal.trap(signal) do
            embedded.stop
            exit(0)
          end
        end
      end

      def print_summary(app_config, sidekiq_config, recovered_files)
        @stdout.puts('Continuous mode started')
        @stdout.puts("Redis URL: #{app_config.dig(:redis, :url)}")
        @stdout.puts("Queues: #{Array(sidekiq_config.fetch('queues', ['continuous'])).join(', ')}")
        @stdout.puts("Recovered files: #{recovered_files.size}")
      end
    end
  end
end
