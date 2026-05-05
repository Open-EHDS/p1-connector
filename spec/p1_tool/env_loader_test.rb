# frozen_string_literal: true

require_relative '../test_helper'

describe P1Tool::EnvLoader do
  before do
    P1Tool::EnvLoader.remove_instance_variable(:@loaded) if P1Tool::EnvLoader.instance_variable_defined?(:@loaded)
  end

  after do
    ENV.delete('P1_INBOX_PATH')
    ENV.delete('P1_DONE_PATH')
    P1Tool::EnvLoader.remove_instance_variable(:@loaded) if P1Tool::EnvLoader.instance_variable_defined?(:@loaded)
  end

  describe '.load!' do
    it 'loads missing variables from a dotenv file' do
      Dir.mktmpdir do |dir|
        env_path = File.join(dir, '.env')
        File.write(
          env_path,
          <<~ENV_FILE
            P1_INBOX_PATH=./volumes/data/inbox
            P1_DONE_PATH="./volumes/data/done"
          ENV_FILE
        )

        P1Tool::EnvLoader.load!(path: env_path)

        assert_equal './volumes/data/inbox', ENV.fetch('P1_INBOX_PATH')
        assert_equal './volumes/data/done', ENV.fetch('P1_DONE_PATH')
      end
    end

    it 'does not override variables already present in ENV' do
      Dir.mktmpdir do |dir|
        env_path = File.join(dir, '.env')
        File.write(env_path, "P1_INBOX_PATH=./from-dotenv\n")
        ENV['P1_INBOX_PATH'] = './from-process-env'

        P1Tool::EnvLoader.load!(path: env_path)

        assert_equal './from-process-env', ENV.fetch('P1_INBOX_PATH')
      end
    end
  end
end
