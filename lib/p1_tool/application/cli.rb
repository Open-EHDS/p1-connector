# frozen_string_literal: true

require 'optparse'

module P1Tool
  module Application
    # Rubocop metric kept local here because command dispatch and option parsing
    # intentionally live together in one CLI entrypoint.
    # rubocop:disable Metrics/ClassLength
    class CLI
      DEFAULT_CONFIG_PATH = File.expand_path('../../../config/config.yml', __dir__)
      HELP_COMMANDS = [nil, 'help', '--help', '-h'].freeze
      VERSION_COMMANDS = %w[version --version -v].freeze
      COMMAND_HANDLERS = {
        'run-once' => :run_once,
        'watch' => :run_watch,
        'recover' => :run_recover,
        'verify' => :run_verify
      }.freeze

      def self.start(argv, stdout: $stdout, stderr: $stderr)
        new(argv, stdout: stdout, stderr: stderr).start
      end

      def initialize(argv, stdout:, stderr:)
        @argv = argv.dup
        @stdout = stdout
        @stderr = stderr
      end

      def start
        command = @argv.shift
        return print_help if HELP_COMMANDS.include?(command)
        return print_version if VERSION_COMMANDS.include?(command)

        handler = COMMAND_HANDLERS[command]
        return send(handler, @argv) if handler

        print_unknown_command(command)
      end

      private

      def run_once(argv)
        options, parser = parse_run_once_options(argv)
        result = build_task_processor(options).call

        print_run_once_summary(result, options[:output_path])
        result.fetch(:result_kind) == 'success' ? 0 : 1
      rescue OptionParser::ParseError => e
        @stderr.puts(e.message)
        @stderr.puts(parser)
        1
      rescue P1Tool::ConfigurationError => e
        print_configuration_error(e)
        1
      end

      def run_verify(argv)
        options, parser = parse_verify_options(argv)
        config = load_configuration(options[:config_path])

        print_verify_summary(config, options[:config_path])
        0
      rescue OptionParser::ParseError => e
        @stderr.puts(e.message)
        @stderr.puts(parser)
        1
      rescue P1Tool::ConfigurationError => e
        print_configuration_error(e)
        1
      end

      def help_text
        <<~TEXT
          Usage: p1-tool <command> [options]

          Commands:
            run-once --input PATH --output PATH [--config PATH]
                                   Process one input file end-to-end
            watch [--config PATH] [--sidekiq-config PATH] [--sidekiq-cron-config PATH]
                                 Start continuous mode with Sidekiq and Redis
            recover [--config PATH] Recover files from processing back to inbox
            verify [--config PATH]  Load and validate the application config
            version                 Print the application version
            help                    Show this help message
        TEXT
      end

      def ensure_required_options!(options, *keys)
        missing = keys.reject { |key| options[key] }
        return if missing.empty?

        names = missing.map { |key| "--#{key.to_s.delete_suffix('_path').tr('_', '-')}" }
        raise OptionParser::MissingArgument, names.join(', ')
      end

      def parse_run_once_options(argv)
        options = { config_path: DEFAULT_CONFIG_PATH }
        parser = OptionParser.new do |opts|
          opts.banner = 'Usage: p1-tool run-once --input PATH --output PATH [--config PATH]'
          opts.on('--input PATH', 'Path to the input JSON file') { |path| options[:input_path] = path }
          opts.on('--output PATH', 'Path to the output result JSON file') { |path| options[:output_path] = path }
          opts.on('--config PATH', 'Path to the YAML config file') { |path| options[:config_path] = path }
        end

        parser.parse!(argv)
        raise OptionParser::InvalidOption, argv.join(' ') unless argv.empty?

        ensure_required_options!(options, :input_path, :output_path)
        [options, parser]
      end

      def parse_verify_options(argv)
        options = { config_path: DEFAULT_CONFIG_PATH }
        parser = OptionParser.new do |opts|
          opts.banner = 'Usage: p1-tool verify [--config PATH]'
          opts.on('--config PATH', 'Path to the YAML config file') { |path| options[:config_path] = path }
        end

        parser.parse!(argv)
        raise OptionParser::InvalidOption, argv.join(' ') unless argv.empty?

        [options, parser]
      end

      def run_watch(argv)
        options, parser = parse_watch_options(argv)

        P1Tool::Runtime::ContinuousRunner.new(
          config_path: options[:config_path],
          sidekiq_config_path: options[:sidekiq_config_path],
          sidekiq_cron_config_path: options[:sidekiq_cron_config_path],
          stdout: @stdout
        ).run
        0
      rescue Interrupt
        0
      rescue OptionParser::ParseError => e
        @stderr.puts(e.message)
        @stderr.puts(parser)
        1
      rescue P1Tool::ConfigurationError => e
        print_configuration_error(e)
        1
      end

      def run_recover(argv)
        options, parser = parse_recover_options(argv)
        config = load_configuration(options[:config_path])
        workspace = P1Tool::Runtime::Workspace.new(config)
        workspace.prepare!
        recovered_files = P1Tool::Runtime::ProcessingRecovery.new(workspace).call

        print_recover_summary(recovered_files, options[:config_path])
        0
      rescue OptionParser::ParseError => e
        @stderr.puts(e.message)
        @stderr.puts(parser)
        1
      rescue P1Tool::ConfigurationError => e
        print_configuration_error(e)
        1
      end

      def load_configuration(config_path) = P1Tool::Core::ConfigurationLoader.load(config_path)

      def build_task_processor(options)
        P1Tool::Runtime::TaskProcessor.new(
          load_configuration(options[:config_path]),
          input_path: options[:input_path],
          output_path: options[:output_path]
        )
      end

      def parse_watch_options(argv)
        options = {
          config_path: DEFAULT_CONFIG_PATH,
          sidekiq_config_path: P1Tool::Runtime::ContinuousRunner::DEFAULT_SIDEKIQ_CONFIG_PATH,
          sidekiq_cron_config_path: P1Tool::Runtime::ContinuousRunner::DEFAULT_SIDEKIQ_CRON_CONFIG_PATH
        }
        parser = OptionParser.new do |opts|
          opts.banner = 'Usage: p1-tool watch [--config PATH] [--sidekiq-config PATH] [--sidekiq-cron-config PATH]'
          opts.on('--config PATH', 'Path to the YAML config file') { |path| options[:config_path] = path }
          opts.on('--sidekiq-config PATH', 'Path to the Sidekiq YAML config file') do |path|
            options[:sidekiq_config_path] = path
          end
          opts.on('--sidekiq-cron-config PATH', 'Path to the Sidekiq cron YAML config file') do |path|
            options[:sidekiq_cron_config_path] = path
          end
        end

        parser.parse!(argv)
        raise OptionParser::InvalidOption, argv.join(' ') unless argv.empty?

        [options, parser]
      end

      def parse_recover_options(argv)
        options = { config_path: DEFAULT_CONFIG_PATH }
        parser = OptionParser.new do |opts|
          opts.banner = 'Usage: p1-tool recover [--config PATH]'
          opts.on('--config PATH', 'Path to the YAML config file') { |path| options[:config_path] = path }
        end

        parser.parse!(argv)
        raise OptionParser::InvalidOption, argv.join(' ') unless argv.empty?

        [options, parser]
      end

      def print_run_once_summary(result, output_path)
        print_lines(
          "Execution finished with #{result.fetch(:result_kind)}",
          "Result path: #{File.expand_path(output_path)}",
          "Transport ID: #{result.fetch(:transport_id)}"
        )
      end

      def print_verify_summary(config, config_path)
        print_lines(
          'Configuration OK',
          "Config path: #{File.expand_path(config_path)}",
          "Subject OID: #{config.dig(:subject, :oid)}",
          "Redis URL: #{config.dig(:redis, :url)}"
        )
      end

      def print_recover_summary(recovered_files, config_path)
        print_lines(
          'Recovery finished',
          "Config path: #{File.expand_path(config_path)}",
          "Recovered files: #{recovered_files.size}"
        )
      end

      def print_configuration_error(error)
        @stderr.puts("Configuration error: #{error.message}")
        format_details(error.details).each { |line| @stderr.puts(line) }
      end

      def print_help
        @stdout.puts(help_text)
        0
      end

      def print_version
        @stdout.puts(P1Tool::VERSION)
        0
      end

      def print_unknown_command(command)
        @stderr.puts("Unknown command: #{command}")
        @stderr.puts
        @stderr.puts(help_text)
        1
      end

      def print_lines(*lines)
        lines.each { |line| @stdout.puts(line) }
      end

      def format_details(details, prefix = nil)
        return [] if details.nil? || details.empty?

        details.flat_map do |key, value|
          nested_prefix = [prefix, key].compact.join('.')

          if value.is_a?(Hash)
            format_details(value, nested_prefix)
          else
            messages = Array(value).join(', ')
            ["  - #{nested_prefix}: #{messages}"]
          end
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
