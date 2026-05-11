# frozen_string_literal: true

require 'json'
require 'optparse'
require 'fileutils'
require 'time'

module P1Tool
  module Application
    class LiveSmokeRunner
      DEFAULT_CONFIG_PATH = CLI::DEFAULT_CONFIG_PATH
      DEFAULT_OUTPUT_ROOT = File.expand_path('../../../tmp/live_smoke', __dir__)
      DEFAULT_AUDIT_TAIL = 10

      def self.start(argv, stdout: $stdout, stderr: $stderr, env: ENV)
        new(argv, stdout:, stderr:, env:).start
      end

      def initialize(argv, stdout:, stderr:, env:)
        @argv = argv.dup
        @stdout = stdout
        @stderr = stderr
        @env = env
      end

      def start
        options, parser = parse_options(@argv)
        config = P1Tool::Core::ConfigurationLoader.load(options[:config_path])
        run_dir = resolve_run_dir(options)

        prepare_run_dir(run_dir, clean: options[:clean])
        output_path = File.join(run_dir, 'result.json')
        debug_xml_dir = File.join(run_dir, 'debug_xml')

        exit_code = run_once(options[:config_path], options[:input_path], output_path, debug_xml_dir)

        encounter_result_payload = read_json_file(output_path)
        procedure_step = run_procedure_step(
          options:,
          run_dir:,
          debug_xml_dir:,
          encounter_result_payload:,
          encounter_exit_code: exit_code
        )

        exit_code = procedure_step[:exit_code] if procedure_step[:ran]

        print_summary(
          config:,
          config_path: options[:config_path],
          input_path: options[:input_path],
          output_path:,
          run_dir:,
          debug_xml_dir:,
          exit_code:,
          audit_tail: options[:audit_tail],
          encounter_result_payload:,
          procedure_step:
        )

        exit_code
      rescue OptionParser::ParseError => e
        @stderr.puts(e.message)
        @stderr.puts(parser)
        1
      rescue P1Tool::ConfigurationError => e
        @stderr.puts("Configuration error: #{e.message}")
        1
      end

      private

      def parse_options(argv)
        options = {
          config_path: DEFAULT_CONFIG_PATH,
          audit_tail: DEFAULT_AUDIT_TAIL
        }
        parser = OptionParser.new do |opts|
          opts.banner = 'Usage: p1-live-smoke --input PATH [--procedure-input PATH] [--config PATH] [--output-dir PATH] [--audit-tail N] [--clean]'
          opts.on('--input PATH', 'Path to the input JSON file') { |path| options[:input_path] = path }
          opts.on('--procedure-input PATH', 'Optional path to register_procedure input JSON file') do |path|
            options[:procedure_input_path] = path
          end
          opts.on('--config PATH', 'Path to the YAML config file') { |path| options[:config_path] = path }
          opts.on('--output-dir PATH', 'Directory for smoke test artifacts') { |path| options[:output_dir] = path }
          opts.on('--audit-tail N', Integer, 'Number of audit entries to print (default: 10)') do |value|
            options[:audit_tail] = value
          end
          opts.on('--clean', 'Remove the output directory before running') { options[:clean] = true }
        end

        parser.parse!(argv)
        raise OptionParser::InvalidOption, argv.join(' ') unless argv.empty?
        raise OptionParser::MissingArgument, '--input' unless options[:input_path]
        raise OptionParser::InvalidArgument, '--audit-tail must be greater than 0' if options[:audit_tail].to_i <= 0

        [options, parser]
      end

      def resolve_run_dir(options)
        return File.expand_path(options[:output_dir]) if options[:output_dir]

        timestamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
        File.join(DEFAULT_OUTPUT_ROOT, timestamp)
      end

      def prepare_run_dir(run_dir, clean:)
        FileUtils.rm_rf(run_dir) if clean
        FileUtils.mkdir_p(run_dir)
      end

      def with_debug_xml(debug_xml_dir)
        previous_debug_xml = @env.key?('P1_DEBUG_XML') ? @env['P1_DEBUG_XML'] : :__missing__
        previous_debug_xml_path = @env.key?('P1_DEBUG_XML_PATH') ? @env['P1_DEBUG_XML_PATH'] : :__missing__

        @env['P1_DEBUG_XML'] = '1'
        @env['P1_DEBUG_XML_PATH'] = debug_xml_dir
        yield
      ensure
        restore_env('P1_DEBUG_XML', previous_debug_xml)
        restore_env('P1_DEBUG_XML_PATH', previous_debug_xml_path)
      end

      def restore_env(key, previous_value)
        if previous_value == :__missing__
          @env.delete(key)
        else
          @env[key] = previous_value
        end
      end

      def run_once(config_path, input_path, output_path, debug_xml_dir)
        with_debug_xml(debug_xml_dir) do
          CLI.start(
            ['run-once', '--config', config_path, '--input', input_path, '--output', output_path],
            stdout: @stdout,
            stderr: @stderr
          )
        end
      end

      def run_procedure_step(options:, run_dir:, debug_xml_dir:, encounter_result_payload:, encounter_exit_code:)
        return { ran: false } unless options[:procedure_input_path]
        return { ran: false, skipped: true } unless encounter_exit_code.zero?

        encounter_reference_id = encounter_result_payload&.dig('details', 'submission', 'reference_id')
        raise "Encounter smoke did not produce submission.reference_id required for procedure step" if blank?(encounter_reference_id)

        procedure_input_payload = read_json_file(options[:procedure_input_path])
        raise "Procedure input file is invalid JSON: #{options[:procedure_input_path]}" if procedure_input_payload.nil?

        resolved_input_payload = build_procedure_input(procedure_input_payload, encounter_reference_id)
        resolved_input_path = File.join(run_dir, 'procedure-input.resolved.json')
        procedure_output_path = File.join(run_dir, 'procedure-result.json')

        write_json_file(resolved_input_path, resolved_input_payload)
        exit_code = run_once(options[:config_path], resolved_input_path, procedure_output_path, debug_xml_dir)

        {
          ran: true,
          exit_code:,
          input_path: options[:procedure_input_path],
          resolved_input_path:,
          output_path: procedure_output_path,
          result_payload: read_json_file(procedure_output_path)
        }
      end

      def build_procedure_input(input_payload, encounter_reference_id)
        payload = deep_copy(input_payload)
        payload['payload'] ||= {}
        payload['payload']['encounter'] ||= {}
        payload['payload']['encounter']['resource_id'] = encounter_reference_id
        payload
      end

      def deep_copy(value)
        JSON.parse(JSON.generate(value))
      end

      def write_json_file(path, payload)
        File.write(path, JSON.pretty_generate(payload) + "\n")
      end

      def print_summary(config:, config_path:, input_path:, output_path:, run_dir:, debug_xml_dir:, exit_code:, audit_tail:, encounter_result_payload:, procedure_step:)
        encounter_transport_id = encounter_result_payload&.fetch('transport_id', nil)

        print_lines(
          'Live smoke finished',
          "Exit code: #{exit_code}",
          "Config path: #{File.expand_path(config_path)}",
          "Input path: #{File.expand_path(input_path)}",
          "Run dir: #{run_dir}",
          "Result path: #{output_path}",
          "Debug XML dir: #{debug_xml_dir}",
          "Audit log path: #{File.expand_path(config.dig(:paths, :audit_log))}",
          "Transport ID: #{encounter_transport_id || 'n/a'}",
          "Result kind: #{encounter_result_payload&.fetch('result_kind', nil) || 'n/a'}"
        )

        print_step_audit(
          title: 'Recent audit events:',
          path: config.dig(:paths, :audit_log),
          transport_id: encounter_transport_id,
          limit: audit_tail
        )

        print_procedure_step_summary(config:, procedure_step:, audit_tail:)
      end

      def print_procedure_step_summary(config:, procedure_step:, audit_tail:)
        if procedure_step[:skipped]
          @stdout.puts('Procedure step: skipped because encounter step did not finish with success')
          return
        end
        return unless procedure_step[:ran]

        result_payload = procedure_step[:result_payload]
        transport_id = result_payload&.fetch('transport_id', nil)

        print_lines(
          "Procedure input path: #{File.expand_path(procedure_step[:input_path])}",
          "Procedure resolved input path: #{procedure_step[:resolved_input_path]}",
          "Procedure result path: #{procedure_step[:output_path]}",
          "Procedure transport ID: #{transport_id || 'n/a'}",
          "Procedure result kind: #{result_payload&.fetch('result_kind', nil) || 'n/a'}"
        )

        print_step_audit(
          title: 'Recent procedure audit events:',
          path: config.dig(:paths, :audit_log),
          transport_id:,
          limit: audit_tail
        )
      end

      def print_step_audit(title:, path:, transport_id:, limit:)
        audit_entries = load_audit_entries(path, transport_id:, limit:)
        return if audit_entries.empty?

        @stdout.puts(title)
        audit_entries.each do |entry|
          @stdout.puts(
            "- #{entry.fetch('timestamp')} #{entry.fetch('event_type')} result=#{entry.fetch('result', 'n/a')}"
          )
        end
      end

      def print_lines(*lines)
        lines.each { |line| @stdout.puts(line) }
      end

      def read_json_file(path)
        return nil unless File.file?(path)

        JSON.parse(File.read(path))
      end

      def load_audit_entries(path, transport_id:, limit:)
        return [] unless File.file?(path)

        entries = File.readlines(path, chomp: true).filter_map do |line|
          next if line.strip.empty?

          JSON.parse(line)
        end
        entries = entries.select { |entry| entry['transport_id'] == transport_id } if transport_id
        entries.last(limit)
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end
    end
  end
end
