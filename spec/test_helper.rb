# frozen_string_literal: true

ENV['APP_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride' if ENV['MINITEST_PRIDE'] == '1' || $stdout.tty?
require 'tmpdir'
require 'stringio'
require 'json'
require 'fileutils'
require 'timeout'

require_relative '../lib/p1_tool'

module RuntimeConfigHelper
  def runtime_config_for(root_dir, redis_url: 'redis://localhost:6379/0', audit_log_path: nil)
    {
      paths: runtime_paths_for(root_dir, audit_log_path:),
      redis: { url: redis_url },
      signature_service: { url: 'http://localhost:8080' },
      subject: runtime_subject_config,
      certificates: runtime_certificates_config
    }
  end

  def runtime_paths_for(root_dir, audit_log_path: nil)
    {
      inbox: File.join(root_dir, 'inbox'),
      processing: File.join(root_dir, 'processing'),
      done: File.join(root_dir, 'done'),
      invalid: File.join(root_dir, 'invalid'),
      results: File.join(root_dir, 'results'),
      audit_log: audit_log_path || File.join(root_dir, 'logs', 'audit.jsonl')
    }
  end

  def runtime_subject_config
    {
      oid: '1.2.616.1.113883.3.4424.1.1',
      identification_code: '1234567890',
      department_code_v: '1234',
      department_code_vii: '1234567',
      is_practice: false,
      medical_chamber: 'NIL'
    }
  end

  def runtime_certificates_config
    {
      base_path: '/certs',
      signing: { filename: 'signing.p12', password_env: 'SIGNING_CERT_PASSWORD' },
      tls: { filename: 'tls.p12', password_env: 'TLS_CERT_PASSWORD' }
    }
  end
end

module FixtureHelper
  def fixture_path(*parts)
    File.join(__dir__, 'fixtures', *parts)
  end

  def fixture_text(*parts)
    File.read(fixture_path(*parts))
  end

  def fixture_json(*parts)
    JSON.parse(fixture_text(*parts))
  end

  def write_config_fixture(target_path, fixture_name:, replacements: {})
    content = fixture_text('config', fixture_name)
    replacements.each do |placeholder, value|
      content = content.gsub(placeholder, value)
    end

    FileUtils.mkdir_p(File.dirname(target_path))
    File.write(target_path, content)
    target_path
  end

  def with_singleton_stub(target, method_name, replacement)
    singleton_class = class << target; self; end
    original_defined = singleton_class.method_defined?(method_name) ||
                       singleton_class.private_method_defined?(method_name)
    original_method = target.method(method_name) if original_defined
    own_method_defined = singleton_method_defined?(singleton_class, method_name)

    singleton_class.send(:remove_method, method_name) if own_method_defined

    singleton_class.send(:define_method, method_name) do |*args, **kwargs, &block|
      replacement.call(*args, **kwargs, &block)
    end

    yield
  ensure
    singleton_class.send(:remove_method, method_name) if singleton_class.method_defined?(method_name)

    if original_defined
      singleton_class.send(:define_method, method_name) do |*args, **kwargs, &block|
        original_method.call(*args, **kwargs, &block)
      end
    end
  end

  def singleton_method_defined?(singleton_class, method_name)
    singleton_class.method_defined?(method_name, false) ||
      singleton_class.private_method_defined?(method_name, false)
  end

  def wait_until(timeout: 20, interval: 0.2)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

    loop do
      return if yield

      raise "Condition not met within #{timeout} seconds" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep interval
    end
  end

  def wait_for_redis(url, timeout: 20)
    pool = Sidekiq::RedisConnection.create(url:, size: 1)

    Timeout.timeout(timeout) do
      loop do
        begin
          response = pool.with { |conn| conn.call('PING') }
          return if response == 'PONG'
        rescue StandardError
          nil
        end

        sleep 0.2
      end
    end
  rescue Timeout::Error
    raise "Redis at #{url} did not become ready within #{timeout} seconds"
  ensure
    pool&.shutdown { |conn| conn.close }
  end
end

module Minitest
  class Test
    include FixtureHelper
    include RuntimeConfigHelper
  end
end
