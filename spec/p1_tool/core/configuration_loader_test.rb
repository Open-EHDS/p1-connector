# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Core::ConfigurationLoader do
  describe '.load' do
    it 'returns symbolized config hash' do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, 'config.yml')
        write_config_fixture(
          config_path,
          fixture_name: 'runtime_config.yml',
          replacements: { '__AUDIT_LOG_PATH__' => '/logs/audit.jsonl' }
        )

        config = with_stubbed_pkcs12_validation do
          P1Tool::Core::ConfigurationLoader.load(config_path)
        end

        assert_equal '/data/inbox', config.dig(:paths, :inbox)
        refute config.dig(:subject, :is_practice)
        assert_equal 'WSS_CERT_PASSWORD', config.dig(:certificates, :wss, :password_env)
        assert_equal 'integration', config.dig(:p1, :environment)
      end
    end

    it 'raises for missing required keys' do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, 'config.yml')
        write_config_fixture(
          config_path,
          fixture_name: 'invalid_runtime_config_missing_required.yml',
          replacements: { '__AUDIT_LOG_PATH__' => '/logs/audit.jsonl' }
        )

        error = assert_raises(P1Tool::ConfigurationError) do
          P1Tool::Core::ConfigurationLoader.load(config_path)
        end

        assert_match('Config validation failed', error.message)
        assert_equal ['is missing'], error.details.dig(:paths, :processing)
        assert_equal ['is missing'], error.details[:redis]
      end
    end

    it 'renders erb defaults from base directories' do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, 'config.yml')
        File.write(
          config_path,
          <<~YAML
            paths:
              inbox: <%= ENV['P1_INBOX_PATH'] || "\#{ENV['P1_DATA_ROOT'] || './tmp/data'}/inbox" %>
              processing: <%= ENV['P1_PROCESSING_PATH'] || "\#{ENV['P1_DATA_ROOT'] || './tmp/data'}/processing" %>
              done: <%= ENV['P1_DONE_PATH'] || "\#{ENV['P1_DATA_ROOT'] || './tmp/data'}/done" %>
              invalid: <%= ENV['P1_INVALID_PATH'] || "\#{ENV['P1_DATA_ROOT'] || './tmp/data'}/invalid" %>
              results: <%= ENV['P1_RESULTS_PATH'] || "\#{ENV['P1_DATA_ROOT'] || './tmp/data'}/results" %>
              audit_log: <%= ENV['P1_AUDIT_LOG_PATH'] || "\#{ENV['P1_LOGS_ROOT'] || './tmp/logs'}/audit.jsonl" %>
            redis:
              url: <%= ENV['REDIS_URL'] || 'redis://127.0.0.1:6379/0' %>
            signature_service:
              url: <%= ENV['SIGNATURE_SERVICE_URL'] || 'http://127.0.0.1:8080' %>
            p1:
              environment: <%= ENV['P1_ENVIRONMENT'] || 'integration' %>
            subject:
              oid: "1.2.616.1.113883.3.4424.1.1"
              identification_code: "1234567890"
              department_code_v: "1234"
              department_code_vii: "1234567"
              is_practice: false
              medical_chamber: "NIL"
            certificates:
              base_path: <%= ENV['P1_CERTIFICATES_BASE_PATH'] || './tmp/certs' %>
              wss:
                filename: wss.p12
                password_env: WSS_CERT_PASSWORD
              tls:
                filename: tls.p12
                password_env: TLS_CERT_PASSWORD
          YAML
        )

        original_data_root = ENV.fetch('P1_DATA_ROOT', nil)
        original_logs_root = ENV.fetch('P1_LOGS_ROOT', nil)
        original_redis_url = ENV.fetch('REDIS_URL', nil)
        original_inbox_path = ENV.fetch('P1_INBOX_PATH', nil)
        original_processing_path = ENV.fetch('P1_PROCESSING_PATH', nil)
        original_done_path = ENV.fetch('P1_DONE_PATH', nil)
        original_invalid_path = ENV.fetch('P1_INVALID_PATH', nil)
        original_results_path = ENV.fetch('P1_RESULTS_PATH', nil)
        original_audit_log_path = ENV.fetch('P1_AUDIT_LOG_PATH', nil)
        original_certificates_base_path = ENV.fetch('P1_CERTIFICATES_BASE_PATH', nil)
        ENV.delete('P1_INBOX_PATH')
        ENV.delete('P1_PROCESSING_PATH')
        ENV.delete('P1_DONE_PATH')
        ENV.delete('P1_INVALID_PATH')
        ENV.delete('P1_RESULTS_PATH')
        ENV.delete('P1_AUDIT_LOG_PATH')
        ENV.delete('P1_CERTIFICATES_BASE_PATH')
        ENV['P1_DATA_ROOT'] = './runtime/data'
        ENV['P1_LOGS_ROOT'] = './runtime/logs'
        ENV['REDIS_URL'] = 'redis://redis:6379/0'
        config = with_stubbed_pkcs12_validation do
          P1Tool::Core::ConfigurationLoader.load(config_path)
        end

        assert_equal './runtime/data/inbox', config.dig(:paths, :inbox)
        assert_equal './runtime/data/results', config.dig(:paths, :results)
        assert_equal './runtime/logs/audit.jsonl', config.dig(:paths, :audit_log)
        assert_equal 'redis://redis:6379/0', config.dig(:redis, :url)
        assert_equal './tmp/certs', config.dig(:certificates, :base_path)
      ensure
        ENV['P1_DATA_ROOT'] = original_data_root
        ENV['P1_LOGS_ROOT'] = original_logs_root
        ENV['REDIS_URL'] = original_redis_url
        ENV['P1_INBOX_PATH'] = original_inbox_path
        ENV['P1_PROCESSING_PATH'] = original_processing_path
        ENV['P1_DONE_PATH'] = original_done_path
        ENV['P1_INVALID_PATH'] = original_invalid_path
        ENV['P1_RESULTS_PATH'] = original_results_path
        ENV['P1_AUDIT_LOG_PATH'] = original_audit_log_path
        ENV['P1_CERTIFICATES_BASE_PATH'] = original_certificates_base_path
      end
    end

    it 'prefers explicit path override over base directory' do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, 'config.yml')
        File.write(
          config_path,
          <<~YAML
            paths:
              inbox: <%= ENV['P1_INBOX_PATH'] || "\#{ENV['P1_DATA_ROOT'] || './tmp/data'}/inbox" %>
              processing: <%= ENV['P1_PROCESSING_PATH'] || "\#{ENV['P1_DATA_ROOT'] || './tmp/data'}/processing" %>
              done: <%= ENV['P1_DONE_PATH'] || "\#{ENV['P1_DATA_ROOT'] || './tmp/data'}/done" %>
              invalid: <%= ENV['P1_INVALID_PATH'] || "\#{ENV['P1_DATA_ROOT'] || './tmp/data'}/invalid" %>
              results: <%= ENV['P1_RESULTS_PATH'] || "\#{ENV['P1_DATA_ROOT'] || './tmp/data'}/results" %>
              audit_log: <%= ENV['P1_AUDIT_LOG_PATH'] || "\#{ENV['P1_LOGS_ROOT'] || './tmp/logs'}/audit.jsonl" %>
            redis:
              url: redis://127.0.0.1:6379/0
            signature_service:
              url: http://127.0.0.1:8080
            p1:
              environment: integration
            subject:
              oid: "1.2.616.1.113883.3.4424.1.1"
              identification_code: "1234567890"
              department_code_v: "1234"
              department_code_vii: "1234567"
              is_practice: false
              medical_chamber: "NIL"
            certificates:
              base_path: ./tmp/certs
              wss:
                filename: wss.p12
                password_env: WSS_CERT_PASSWORD
              tls:
                filename: tls.p12
                password_env: TLS_CERT_PASSWORD
          YAML
        )

        original_data_root = ENV.fetch('P1_DATA_ROOT', nil)
        original_inbox_path = ENV.fetch('P1_INBOX_PATH', nil)
        original_processing_path = ENV.fetch('P1_PROCESSING_PATH', nil)
        ENV.delete('P1_PROCESSING_PATH')
        ENV['P1_DATA_ROOT'] = './runtime/data'
        ENV['P1_INBOX_PATH'] = '/custom/inbox'

        config = with_stubbed_pkcs12_validation do
          P1Tool::Core::ConfigurationLoader.load(config_path)
        end

        assert_equal '/custom/inbox', config.dig(:paths, :inbox)
        assert_equal './runtime/data/processing', config.dig(:paths, :processing)
      ensure
        ENV['P1_DATA_ROOT'] = original_data_root
        ENV['P1_INBOX_PATH'] = original_inbox_path
        ENV['P1_PROCESSING_PATH'] = original_processing_path
      end
    end

    it 'raises when erb requires a missing environment variable' do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, 'config.yml')
        File.write(
          config_path,
          <<~YAML
            paths:
              inbox: ./tmp/inbox
              processing: ./tmp/processing
              done: ./tmp/done
              invalid: ./tmp/invalid
              results: ./tmp/results
              audit_log: ./tmp/audit.jsonl
            redis:
              url: <%= ENV.fetch('REDIS_URL') %>
            signature_service:
              url: http://127.0.0.1:8080
            p1:
              environment: integration
            subject:
              oid: "1.2.616.1.113883.3.4424.1.1"
              identification_code: "1234567890"
              department_code_v: "1234"
              department_code_vii: "1234567"
              is_practice: false
              medical_chamber: "NIL"
            certificates:
              base_path: ./tmp/certs
              wss:
                filename: wss.p12
                password_env: WSS_CERT_PASSWORD
              tls:
                filename: tls.p12
                password_env: TLS_CERT_PASSWORD
          YAML
        )

        original_redis_url = ENV.fetch('REDIS_URL', nil)
        ENV.delete('REDIS_URL')
        error = assert_raises(P1Tool::ConfigurationError) do
          P1Tool::Core::ConfigurationLoader.load(config_path)
        end

        assert_match('Invalid ERB', error.message)
        assert_match("key not found: \"REDIS_URL\"", error.message)
      ensure
        ENV['REDIS_URL'] = original_redis_url
      end
    end

    it 'raises when certificate password env is missing' do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, 'config.yml')
        write_config_fixture(
          config_path,
          fixture_name: 'runtime_config.yml',
          replacements: { '__AUDIT_LOG_PATH__' => '/logs/audit.jsonl' }
        )

        original_wss = ENV.fetch('WSS_CERT_PASSWORD', nil)
        original_tls = ENV.fetch('TLS_CERT_PASSWORD', nil)
        ENV.delete('WSS_CERT_PASSWORD')
        ENV['TLS_CERT_PASSWORD'] = 'secret'

        error = assert_raises(P1Tool::ConfigurationError) do
          with_singleton_stub(
            P1Tool::Gateways::P1::Pkcs12Bundle,
            :load,
            ->(path:, password:) { Struct.new(:certificate, :key, :ca_certs).new(nil, nil, []) }
          ) do
            P1Tool::Core::ConfigurationLoader.load(config_path)
          end
        end

        assert_equal ['environment variable WSS_CERT_PASSWORD is missing'], error.details.dig(:certificates, :wss, :password_env)
      ensure
        ENV['WSS_CERT_PASSWORD'] = original_wss
        ENV['TLS_CERT_PASSWORD'] = original_tls
      end
    end
  end
end
