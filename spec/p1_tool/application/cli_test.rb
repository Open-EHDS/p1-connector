# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::CLI do
  let(:tmpdir) { Dir.mktmpdir }
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:config_path) { File.join(tmpdir, 'config.yml') }
  let(:input_path) { File.join(tmpdir, 'input.json') }
  let(:output_path) { File.join(tmpdir, 'results', 'output.json') }
  let(:audit_log_path) { File.join(tmpdir, 'audit', 'audit.jsonl') }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe '.start' do
    it 'lists run-once and verify options in help' do
      exit_code = P1Tool::CLI.start([], stdout: stdout, stderr: stderr)

      assert_equal 0, exit_code
      assert_includes stdout.string, 'run-once --input PATH --output PATH [--config PATH]'
      assert_includes stdout.string, 'verify [--config PATH]'
      assert_empty stderr.string
    end

    describe 'run-once' do
      before do
        write_config_fixture(
          config_path,
          fixture_name: 'runtime_config.yml',
          replacements: { '__AUDIT_LOG_PATH__' => audit_log_path }
        )
      end

      it 'processes valid input file' do
        File.write(input_path, JSON.pretty_generate(fixture_json('runtime', 'valid_input.json')))

        exit_code = P1Tool::CLI.start(
          ['run-once', '--config', config_path, '--input', input_path, '--output', output_path],
          stdout: stdout,
          stderr: stderr
        )

        assert_equal 0, exit_code
        assert_includes stdout.string, 'Execution finished with success'
        assert_equal 'success', JSON.parse(File.read(output_path)).fetch('result_kind')
        assert_empty stderr.string
      end
    end

    describe 'run-once with invalid input' do
      before do
        write_config_fixture(
          config_path,
          fixture_name: 'runtime_config.yml',
          replacements: { '__AUDIT_LOG_PATH__' => audit_log_path }
        )
      end

      it 'returns non-zero' do
        File.write(
          input_path,
          JSON.pretty_generate(fixture_json('runtime', 'invalid_input_missing_operation_kind.json'))
        )

        exit_code = P1Tool::CLI.start(
          ['run-once', '--config', config_path, '--input', input_path, '--output', output_path],
          stdout: stdout,
          stderr: stderr
        )

        assert_equal 1, exit_code
        assert_includes stdout.string, 'Execution finished with invalid'
        assert_equal 'invalid', JSON.parse(File.read(output_path)).fetch('result_kind')
        assert_empty stderr.string
      end
    end

    describe 'verify' do
      before do
        write_config_fixture(
          config_path,
          fixture_name: 'runtime_config.yml',
          replacements: { '__AUDIT_LOG_PATH__' => '/logs/audit.jsonl' }
        )
      end

      it 'loads and validates config' do
        exit_code = P1Tool::CLI.start(
          ['verify', '--config', config_path],
          stdout: stdout,
          stderr: stderr
        )

        assert_equal 0, exit_code
        assert_includes stdout.string, 'Configuration OK'
        assert_includes stdout.string, File.expand_path(config_path)
        assert_empty stderr.string
      end
    end

    describe 'verify with invalid config' do
      before do
        write_config_fixture(
          config_path,
          fixture_name: 'invalid_runtime_config_missing_required.yml',
          replacements: { '__AUDIT_LOG_PATH__' => '/logs/audit.jsonl' }
        )
      end

      it 'reports configuration errors' do
        exit_code = P1Tool::CLI.start(
          ['verify', '--config', config_path],
          stdout: stdout,
          stderr: stderr
        )

        assert_equal 1, exit_code
        assert_empty stdout.string
        assert_includes stderr.string, 'Configuration error:'
        assert_includes stderr.string, 'paths.processing'
      end
    end
  end
end
