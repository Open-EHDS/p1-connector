# frozen_string_literal: true

require "optparse"

module P1Tool
  module Application
    class CLI
      DEFAULT_CONFIG_PATH = File.expand_path("../../../config/config.yml", __dir__)

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

        case command
        when nil, "help", "--help", "-h"
          @stdout.puts(help_text)
          0
        when "run-once"
          run_once(@argv)
        when "verify"
          run_verify(@argv)
        when "version", "--version", "-v"
          @stdout.puts(P1Tool::VERSION)
          0
        else
          @stderr.puts("Unknown command: #{command}")
          @stderr.puts
          @stderr.puts(help_text)
          1
        end
      end

      private

      def run_once(argv)
        options = { config_path: DEFAULT_CONFIG_PATH }

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: p1-tool run-once --input PATH --output PATH [--config PATH]"
          opts.on("--input PATH", "Path to the input JSON file") { |path| options[:input_path] = path }
          opts.on("--output PATH", "Path to the output result JSON file") { |path| options[:output_path] = path }
          opts.on("--config PATH", "Path to the YAML config file") { |path| options[:config_path] = path }
        end

        parser.parse!(argv)

        unless argv.empty?
          raise OptionParser::InvalidOption, argv.join(" ")
        end

        ensure_required_options!(options, :input_path, :output_path)

        config = P1Tool::Core::ConfigurationLoader.load(options[:config_path])
        result = P1Tool::Runtime::TaskProcessor.new(
          config,
          input_path: options[:input_path],
          output_path: options[:output_path]
        ).call

        @stdout.puts("Execution finished with #{result.fetch(:result_kind)}")
        @stdout.puts("Result path: #{File.expand_path(options[:output_path])}")
        @stdout.puts("Transport ID: #{result.fetch(:transport_id)}")

        result.fetch(:result_kind) == "success" ? 0 : 1
      rescue OptionParser::ParseError => e
        @stderr.puts(e.message)
        @stderr.puts(parser)
        1
      rescue P1Tool::ConfigurationError => e
        @stderr.puts("Configuration error: #{e.message}")
        format_details(e.details).each { |line| @stderr.puts(line) }
        1
      end

      def run_verify(argv)
        options = { config_path: DEFAULT_CONFIG_PATH }

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: p1-tool verify [--config PATH]"
          opts.on("--config PATH", "Path to the YAML config file") do |path|
            options[:config_path] = path
          end
        end

        parser.parse!(argv)

        unless argv.empty?
          raise OptionParser::InvalidOption, argv.join(" ")
        end

        config = P1Tool::Core::ConfigurationLoader.load(options[:config_path])

        @stdout.puts("Configuration OK")
        @stdout.puts("Config path: #{File.expand_path(options[:config_path])}")
        @stdout.puts("Subject OID: #{config.dig(:subject, :oid)}")
        @stdout.puts("Redis URL: #{config.dig(:redis, :url)}")
        0
      rescue OptionParser::ParseError => e
        @stderr.puts(e.message)
        @stderr.puts(parser)
        1
      rescue P1Tool::ConfigurationError => e
        @stderr.puts("Configuration error: #{e.message}")
        format_details(e.details).each { |line| @stderr.puts(line) }
        1
      end

      def help_text
        <<~TEXT
          Usage: p1-tool <command> [options]

          Commands:
            run-once --input PATH --output PATH [--config PATH]
                                   Process one input file end-to-end
            verify [--config PATH]  Load and validate the application config
            version                 Print the application version
            help                    Show this help message
        TEXT
      end

      def ensure_required_options!(options, *keys)
        missing = keys.reject { |key| options[key] }
        return if missing.empty?

        names = missing.map { |key| "--#{key.to_s.delete_suffix('_path').tr('_', '-')}" }
        raise OptionParser::MissingArgument, names.join(", ")
      end

      def format_details(details, prefix = nil)
        return [] if details.nil? || details.empty?

        details.flat_map do |key, value|
          nested_prefix = [prefix, key].compact.join(".")

          if value.is_a?(Hash)
            format_details(value, nested_prefix)
          else
            messages = Array(value).join(", ")
            ["  - #{nested_prefix}: #{messages}"]
          end
        end
      end
    end
  end
end
