# frozen_string_literal: true

ENV['APP_ENV'] = 'test'

require 'simplecov'

test_files = ARGV.grep(/_test\.rb/)
integration_test_files = test_files.select { |path| path.start_with?('spec/p1_tool/integration/') }
simplecov_command_name = if test_files.any? && integration_test_files.size == test_files.size
                           'Minitest Integration'
                         elsif integration_test_files.any?
                           'Minitest Full'
                         else
                           'Minitest Unit'
                         end

SimpleCov.command_name simplecov_command_name
SimpleCov.use_merging false

SimpleCov.start do
  enable_coverage :branch
  primary_coverage :line
  track_files 'lib/**/*.rb'

  add_filter '/spec/'
  add_filter '/coverage/'
  add_filter '/lib/p1_tool/application/live_smoke_runner.rb'

  add_group 'Application', 'lib/p1_tool/application'
  add_group 'Core', 'lib/p1_tool/core'
  add_group 'Gateways', 'lib/p1_tool/gateways'
  add_group 'Runtime', 'lib/p1_tool/runtime'
end

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
      p1: { environment: 'integration' },
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
      medical_chamber: 'NIL',
      name: 'Test Subject',
      regon: '12345678900000',
      address: '00-000 Test, ul. Testowa 1 / 1',
      phone: '123456789'
    }
  end

  def runtime_certificates_config
    {
      base_path: '/certs',
      wss: { filename: 'wss.p12', password_env: 'WSS_CERT_PASSWORD' },
      tls: { filename: 'tls.p12', password_env: 'TLS_CERT_PASSWORD' }
    }
  end

  def build_fake_p1_client(
    encounter_reference_id: 'stub-encounter-1',
    procedure_reference_id: 'stub-procedure-1',
    condition_reference_id: 'stub-condition-1',
    provenance_reference_id: 'stub-provenance-1',
    patient_reference_id: nil,
    patient_version_id: '7',
    access_token: 'stub-access-token'
  )
    Class.new do
      define_method(:initialize) do |encounter_reference_id:, procedure_reference_id:, condition_reference_id:,
                                     provenance_reference_id:, patient_reference_id:, patient_version_id:,
                                     access_token:|
        @encounter_reference_id = encounter_reference_id
        @procedure_reference_id = procedure_reference_id
        @condition_reference_id = condition_reference_id
        @provenance_reference_id = provenance_reference_id
        @patient_reference_id = patient_reference_id
        @patient_version_id = patient_version_id
        @access_token = access_token
      end

      define_method(:access_token) { @access_token }

      define_method(:find_patient) do |payload:|
        pesel = payload.dig(:patient, :pesel)
        patient_id = @patient_reference_id || "stub-patient-#{pesel}"
        {
          status: 200,
          body: {
            'resourceType' => 'Bundle',
            'total' => 1,
            'entry' => [{ 'resource' => { 'id' => patient_id, 'meta' => { 'versionId' => @patient_version_id } } }]
          }
        }
      end

      define_method(:get_resource_xml) do |resource_type:, reference_id:, version_id: nil|
        {
          status: 200,
          body: "<#{resource_type} id=\"#{reference_id}\" version=\"#{version_id}\"/>",
          headers: { 'Content-Type' => 'application/fhir+xml' }
        }
      end

      define_method(:destroy_resource) do |**_|
        {
          status: 200,
          body: nil,
          headers: {}
        }
      end

      define_method(:create_resource) do |resource_type:, **_|
        case resource_type
        when 'Patient'
          { status: 201, reference_id: 'stub-created-patient', version_id: '1' }
        when 'Procedure'
          { status: 201, reference_id: @procedure_reference_id, version_id: '1' }
        when 'Condition'
          { status: 201, reference_id: @condition_reference_id, version_id: '1' }
        when 'Provenance'
          { status: 201, reference_id: @provenance_reference_id, version_id: '1' }
        else
          { status: 201, reference_id: @encounter_reference_id, version_id: '1' }
        end
      end

      define_method(:update_resource) do |reference_id:, **_|
        { status: 200, reference_id:, version_id: '2' }
      end
    end.new(
      encounter_reference_id:,
      procedure_reference_id:,
      condition_reference_id:,
      provenance_reference_id:,
      patient_reference_id:,
      patient_version_id:,
      access_token:
    )
  end

  def with_fake_p1_client_factory(client = build_fake_p1_client, &)
    with_singleton_stub(
      P1Tool::Gateways::P1::ClientFactory,
      :build,
      ->(**_) { client },
      &
    )
  end

  def with_stubbed_pkcs12_validation(
    password_envs: { 'WSS_CERT_PASSWORD' => 'secret', 'TLS_CERT_PASSWORD' => 'secret' },
    &
  )
    original = {}
    password_envs.each do |key, value|
      original[key] = ENV.key?(key) ? ENV[key] : :__missing__
      ENV[key] = value
    end

    with_singleton_stub(
      P1Tool::Gateways::P1::Pkcs12Bundle,
      :load,
      ->(**_) { Struct.new(:certificate, :key, :ca_certs).new(nil, nil, []) },
      &
    )
  ensure
    password_envs.each_key do |key|
      if original[key] == :__missing__
        ENV.delete(key)
      else
        ENV[key] = original[key]
      end
    end
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
    pool&.shutdown(&:close)
  end

  def redis_available?(url, timeout: 2)
    pool = Sidekiq::RedisConnection.create(url:, size: 1)

    Timeout.timeout(timeout) do
      loop do
        begin
          response = pool.with { |conn| conn.call('PING') }
          return true if response == 'PONG'
        rescue StandardError
          nil
        end

        sleep 0.2
      end
    end
  rescue Timeout::Error
    false
  ensure
    pool&.shutdown(&:close)
  end
end

module Minitest
  class Test
    include FixtureHelper
    include RuntimeConfigHelper
  end
end
