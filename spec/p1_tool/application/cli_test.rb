# frozen_string_literal: true

require_relative '../../test_helper'
require 'yaml'

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
      assert_includes stdout.string, 'watch [--config PATH] [--sidekiq-config PATH] [--sidekiq-cron-config PATH]'
      assert_includes stdout.string, 'recover [--config PATH] Recover files from processing back to inbox'
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
        File.write(input_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))

        exit_code = with_stubbed_pkcs12_validation do
          with_fake_p1_client_factory do
            P1Tool::CLI.start(
              ['run-once', '--config', config_path, '--input', input_path, '--output', output_path],
              stdout: stdout,
              stderr: stderr
            )
          end
        end

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

        exit_code = with_stubbed_pkcs12_validation do
          P1Tool::CLI.start(
            ['run-once', '--config', config_path, '--input', input_path, '--output', output_path],
            stdout: stdout,
            stderr: stderr
          )
        end

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
        exit_code = with_stubbed_pkcs12_validation do
          P1Tool::CLI.start(
            ['verify', '--config', config_path],
            stdout: stdout,
            stderr: stderr
          )
        end

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

    describe 'watch' do
      it 'starts continuous runner with default config paths' do
        init_args = nil
        run_called = false
        runner = Object.new
        runner.define_singleton_method(:run) { run_called = true }

        with_singleton_stub(P1Tool::Runtime::ContinuousRunner, :new, lambda { |**kwargs|
          init_args = kwargs
          runner
        }) do
          exit_code = P1Tool::CLI.start(
            ['watch', '--config', config_path],
            stdout: stdout,
            stderr: stderr
          )

          assert_equal 0, exit_code
        end

        assert_equal File.expand_path(config_path), File.expand_path(init_args.fetch(:config_path))
        assert_equal stdout, init_args.fetch(:stdout)
        assert run_called
        assert_empty stderr.string
      end
    end

    describe 'recover' do
      it 'moves files from processing to inbox' do
        config = runtime_config_for(tmpdir, audit_log_path:)
        File.write(config_path, YAML.dump(JSON.parse(JSON.generate(config))))
        processing_path = File.join(config.dig(:paths, :processing), 'task-1.json')
        FileUtils.mkdir_p(File.dirname(processing_path))
        File.write(processing_path, "{\"task_id\":\"1\"}\n")

        exit_code = with_stubbed_pkcs12_validation do
          P1Tool::CLI.start(
            ['recover', '--config', config_path],
            stdout: stdout,
            stderr: stderr
          )
        end

        assert_equal 0, exit_code
        assert_includes stdout.string, 'Recovery finished'
        assert_includes stdout.string, 'Recovered files: 1'
        assert_path_exists File.join(config.dig(:paths, :inbox), 'task-1.json')
        refute_path_exists processing_path
        assert_empty stderr.string
      end
    end
  end
end
