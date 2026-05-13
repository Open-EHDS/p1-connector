# frozen_string_literal: true

require_relative '../../test_helper'

describe 'continuous mode with compose redis' do
  let(:tmpdir) { Dir.mktmpdir }
  let(:redis_url) { ENV.fetch('INTEGRATION_REDIS_URL', ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0')) }
  let(:config) { runtime_config_for(tmpdir, redis_url:) }

  after do
    P1Tool::Runtime::RuntimeEnvironment.reset!
    Sidekiq.redis { |conn| conn.call('FLUSHDB') }
  rescue StandardError
    nil
  ensure
    FileUtils.rm_rf(tmpdir)
  end

  it 'processes inbox file end-to-end using redis started from docker compose' do
    unless redis_available?(redis_url)
      message = <<~TEXT
        Redis is not available at #{redis_url}.
        Start it with:
        docker compose -f docker-compose.dev.yml up -d redis
      TEXT

      ENV.fetch('REQUIRE_REDIS_INTEGRATION', nil) == '1' ? flunk(message) : skip(message)
    end

    wait_for_redis(redis_url)

    Sidekiq.default_configuration.redis = { url: redis_url }
    Sidekiq.redis { |conn| conn.call('FLUSHDB') }

    P1Tool::Runtime::RuntimeEnvironment.bootstrap!(config:)

    embedded = Sidekiq.configure_embed do |sidekiq_config|
      sidekiq_config.redis = { url: redis_url }
      sidekiq_config.concurrency = 1
      sidekiq_config.queues = ['continuous']
      sidekiq_config.server_middleware do |chain|
        chain.add(P1Tool::Jobs::JobContextMiddleware)
      end
    end

    embedded.run

    begin
      inbox_path = File.join(config.dig(:paths, :inbox), 'task-1.json')
      result_path = File.join(config.dig(:paths, :results), 'task-1.json.result.json')
      done_path = File.join(config.dig(:paths, :done), 'task-1.json')
      processing_path = File.join(config.dig(:paths, :processing), 'task-1.json')

      File.write(inbox_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))

      with_fake_p1_client_factory do
        P1Tool::Jobs::InboxScanJob.perform_async

        wait_until(timeout: 20) { File.exist?(result_path) && File.exist?(done_path) }
      end

      persisted_result = JSON.parse(File.read(result_path))

      assert_equal 'success', persisted_result.fetch('result_kind')
      assert_path_exists done_path
      refute_path_exists inbox_path
      refute_path_exists processing_path
    ensure
      embedded.stop
    end
  end
end
