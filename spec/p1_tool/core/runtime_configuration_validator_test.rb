# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Core::RuntimeConfigurationValidator do
  let(:validator_class) { P1Tool::Core::RuntimeConfigurationValidator }
  let(:tmpdir) { Dir.mktmpdir }
  let(:config_path) { File.join(tmpdir, 'config.yml') }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  it 'validates configured certificates' do
    write_config_fixture(
      config_path,
      fixture_name: 'runtime_config.yml',
      replacements: { '__AUDIT_LOG_PATH__' => '/logs/audit.jsonl' }
    )
    config = P1Tool::Core::ConfigurationLoader.load(config_path)

    load_calls = []
    result = with_certificate_envs do
      with_singleton_stub(
        P1Tool::Gateways::P1::Pkcs12Bundle,
        :load,
        lambda do |path:, password:|
          load_calls << { path:, password: }
          Struct.new(:certificate, :key, :ca_certs).new(nil, nil, [])
        end
      ) do
        validator_class.validate!(config, path: config_path)
      end
    end

    assert_same config, result
    assert_equal [
      { path: '/certs/wss.p12', password: 'wss-secret' },
      { path: '/certs/tls.p12', password: 'tls-secret' }
    ], load_calls
  end

  it 'raises when certificate password env is missing' do
    write_config_fixture(
      config_path,
      fixture_name: 'runtime_config.yml',
      replacements: { '__AUDIT_LOG_PATH__' => '/logs/audit.jsonl' }
    )
    config = P1Tool::Core::ConfigurationLoader.load(config_path)

    original_wss = ENV.fetch('WSS_CERT_PASSWORD', nil)
    original_tls = ENV.fetch('TLS_CERT_PASSWORD', nil)
    ENV.delete('WSS_CERT_PASSWORD')
    ENV['TLS_CERT_PASSWORD'] = 'tls-secret'

    error = assert_raises(P1Tool::ConfigurationError) do
      with_singleton_stub(
        P1Tool::Gateways::P1::Pkcs12Bundle,
        :load,
        ->(**_kwargs) { Struct.new(:certificate, :key, :ca_certs).new(nil, nil, []) }
      ) do
        validator_class.validate!(config, path: config_path)
      end
    end

    assert_match('Runtime configuration validation failed', error.message)
    assert_equal ['environment variable WSS_CERT_PASSWORD is missing'],
                 error.details.dig(:certificates, :wss, :password_env)
  ensure
    ENV['WSS_CERT_PASSWORD'] = original_wss
    ENV['TLS_CERT_PASSWORD'] = original_tls
  end

  it 'wraps certificate loading errors as configuration errors' do
    write_config_fixture(
      config_path,
      fixture_name: 'runtime_config.yml',
      replacements: { '__AUDIT_LOG_PATH__' => '/logs/audit.jsonl' }
    )
    config = P1Tool::Core::ConfigurationLoader.load(config_path)

    error = assert_raises(P1Tool::ConfigurationError) do
      with_certificate_envs do
        with_singleton_stub(
          P1Tool::Gateways::P1::Pkcs12Bundle,
          :load,
          ->(**_kwargs) { raise OpenSSL::PKCS12::PKCS12Error, 'invalid password' }
        ) do
          validator_class.validate!(config, path: config_path)
        end
      end
    end

    assert_match('Runtime configuration validation failed', error.message)
    assert_equal ['invalid password'], error.details.dig(:certificates, :wss, :filename)
  end

  private

  def with_certificate_envs
    original_wss = ENV.fetch('WSS_CERT_PASSWORD', nil)
    original_tls = ENV.fetch('TLS_CERT_PASSWORD', nil)
    ENV['WSS_CERT_PASSWORD'] = 'wss-secret'
    ENV['TLS_CERT_PASSWORD'] = 'tls-secret'
    yield
  ensure
    ENV['WSS_CERT_PASSWORD'] = original_wss
    ENV['TLS_CERT_PASSWORD'] = original_tls
  end
end
