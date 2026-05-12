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
        condition_step = run_condition_step(
          options:,
          run_dir:,
          debug_xml_dir:,
          encounter_result_payload:,
          encounter_exit_code: exit_code
        )
        provenance_step = run_provenance_step(
          options:,
          run_dir:,
          debug_xml_dir:,
          encounter_result_payload:,
          encounter_exit_code: exit_code,
          procedure_step:,
          condition_step:
        )
        cleanup_steps = run_cleanup_steps(
          options:,
          run_dir:,
          debug_xml_dir:,
          encounter_result_payload:,
          procedure_step:,
          condition_step:,
          provenance_step:
        )

        exit_code = overall_exit_code(exit_code, procedure_step, condition_step, provenance_step, *cleanup_steps)

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
          procedure_step:,
          condition_step:,
          provenance_step:,
          cleanup_steps:
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
          opts.banner = 'Usage: p1-live-smoke --input PATH [--procedure-input PATH] [--condition-input PATH] [--provenance-input PATH] [--config PATH] [--output-dir PATH] [--audit-tail N] [--clean]'
          opts.on('--input PATH', 'Path to the input JSON file') { |path| options[:input_path] = path }
          opts.on('--procedure-input PATH', 'Optional path to register_procedure input JSON file') do |path|
            options[:procedure_input_path] = path
          end
          opts.on('--condition-input PATH', 'Optional path to register_condition input JSON file') do |path|
            options[:condition_input_path] = path
          end
          opts.on('--provenance-input PATH', 'Optional path to register_provenance input JSON file') do |path|
            options[:provenance_input_path] = path
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
        run_resource_step(
          enabled_path: options[:procedure_input_path],
          config_path: options[:config_path],
          run_dir:,
          debug_xml_dir:,
          encounter_result_payload:,
          encounter_exit_code:,
          step_name: 'procedure'
        )
      end

      def run_condition_step(options:, run_dir:, debug_xml_dir:, encounter_result_payload:, encounter_exit_code:)
        run_resource_step(
          enabled_path: options[:condition_input_path],
          config_path: options[:config_path],
          run_dir:,
          debug_xml_dir:,
          encounter_result_payload:,
          encounter_exit_code:,
          step_name: 'condition'
        )
      end

      def run_provenance_step(options:, run_dir:, debug_xml_dir:, encounter_result_payload:, encounter_exit_code:, procedure_step:, condition_step:)
        return { ran: false } unless options[:provenance_input_path]
        return { ran: false, skipped: true } unless provenance_prerequisites_met?(encounter_exit_code:, procedure_step:, condition_step:)

        input_payload = read_json_file(options[:provenance_input_path])
        raise "Provenance input file is invalid JSON: #{options[:provenance_input_path]}" if input_payload.nil?

        resolved_input_payload = build_provenance_input(
          input_payload:,
          encounter_result_payload:,
          procedure_step:,
          condition_step:
        )
        resolved_input_path = File.join(run_dir, 'provenance-input.resolved.json')
        result_output_path = File.join(run_dir, 'provenance-result.json')

        write_json_file(resolved_input_path, resolved_input_payload)
        exit_code = run_once(options[:config_path], resolved_input_path, result_output_path, debug_xml_dir)

        {
          ran: true,
          step_name: 'provenance',
          exit_code:,
          input_path: options[:provenance_input_path],
          resolved_input_path:,
          output_path: result_output_path,
          result_payload: read_json_file(result_output_path)
        }
      end

      def run_resource_step(enabled_path:, config_path:, run_dir:, debug_xml_dir:, encounter_result_payload:, encounter_exit_code:, step_name:)
        return { ran: false } unless enabled_path
        return { ran: false, skipped: true } unless encounter_exit_code.zero?

        encounter_reference_id = encounter_result_payload&.dig('details', 'submission', 'reference_id')
        raise "Encounter smoke did not produce submission.reference_id required for #{step_name} step" if blank?(encounter_reference_id)

        input_payload = read_json_file(enabled_path)
        raise "#{step_name.capitalize} input file is invalid JSON: #{enabled_path}" if input_payload.nil?

        resolved_input_payload = build_step_input(input_payload, encounter_reference_id)
        resolved_input_path = File.join(run_dir, "#{step_name}-input.resolved.json")
        result_output_path = File.join(run_dir, "#{step_name}-result.json")

        write_json_file(resolved_input_path, resolved_input_payload)
        exit_code = run_once(config_path, resolved_input_path, result_output_path, debug_xml_dir)

        {
          ran: true,
          step_name:,
          exit_code:,
          input_path: enabled_path,
          resolved_input_path:,
          output_path: result_output_path,
          result_payload: read_json_file(result_output_path)
        }
      end

      def build_step_input(input_payload, encounter_reference_id)
        payload = deep_copy(input_payload)
        payload['payload'] ||= {}
        payload['payload']['encounter'] ||= {}
        payload['payload']['encounter']['resource_id'] = encounter_reference_id
        payload
      end

      def build_provenance_input(input_payload:, encounter_result_payload:, procedure_step:, condition_step:)
        payload = deep_copy(input_payload)
        payload['payload'] ||= {}
        payload['payload']['references'] = build_provenance_references(
          encounter_result_payload:,
          procedure_step:,
          condition_step:
        )
        payload
      end

      def build_provenance_references(encounter_result_payload:, procedure_step:, condition_step:)
        patient_reference_id = encounter_result_payload&.dig('details', 'patient_resolution', 'patient_reference_id')
        patient_version_id = encounter_result_payload&.dig('details', 'patient_resolution', 'patient_version_id')
        encounter_reference_id = encounter_result_payload&.dig('details', 'submission', 'reference_id')
        encounter_version_id = encounter_result_payload&.dig('details', 'submission', 'version_id')

        raise 'Encounter smoke did not produce patient reference required for provenance step' if blank?(patient_reference_id)
        raise 'Encounter smoke did not produce patient version required for provenance step' if blank?(patient_version_id)
        raise 'Encounter smoke did not produce encounter reference required for provenance step' if blank?(encounter_reference_id)
        raise 'Encounter smoke did not produce encounter version required for provenance step' if blank?(encounter_version_id)

        references = [
          build_provenance_reference('Patient', patient_reference_id, patient_version_id),
          build_provenance_reference('Encounter', encounter_reference_id, encounter_version_id)
        ]

        append_step_reference(references, procedure_step, 'Procedure')
        append_step_reference(references, condition_step, 'Condition')
        references
      end

      def append_step_reference(references, step, resource_type)
        return unless step[:ran]
        return unless step[:exit_code].zero?

        reference_id = step.dig(:result_payload, 'details', 'submission', 'reference_id')
        version_id = step.dig(:result_payload, 'details', 'submission', 'version_id')
        raise "#{resource_type} smoke did not produce submission.reference_id required for provenance step" if blank?(reference_id)
        raise "#{resource_type} smoke did not produce submission.version_id required for provenance step" if blank?(version_id)

        references << build_provenance_reference(resource_type, reference_id, version_id)
      end

      def build_provenance_reference(resource_type, reference_id, version_id)
        {
          'resource_type' => resource_type,
          'reference_id' => reference_id,
          'version_id' => version_id
        }
      end

      def provenance_prerequisites_met?(encounter_exit_code:, procedure_step:, condition_step:)
        return false unless encounter_exit_code.zero?
        return false if procedure_step[:ran] && !procedure_step[:exit_code].zero?
        return false if condition_step[:ran] && !condition_step[:exit_code].zero?

        true
      end

      def run_cleanup_steps(options:, run_dir:, debug_xml_dir:, encounter_result_payload:, procedure_step:, condition_step:, provenance_step:)
        cleanup_plan(
          options:,
          encounter_result_payload:,
          procedure_step:,
          condition_step:,
          provenance_step:
        ).map do |cleanup_target|
          run_cleanup_step(
            cleanup_target:,
            config_path: options[:config_path],
            run_dir:,
            debug_xml_dir:
          )
        end
      end

      def cleanup_plan(options:, encounter_result_payload:, procedure_step:, condition_step:, provenance_step:)
        [
          build_cleanup_target(
            resource_type: 'Provenance',
            source_input_path: provenance_step[:resolved_input_path] || options[:provenance_input_path],
            result_payload: provenance_step[:result_payload],
            step_name: 'provenance'
          ),
          build_cleanup_target(
            resource_type: 'Condition',
            source_input_path: condition_step[:resolved_input_path] || options[:condition_input_path],
            result_payload: condition_step[:result_payload],
            step_name: 'condition'
          ),
          build_cleanup_target(
            resource_type: 'Procedure',
            source_input_path: procedure_step[:resolved_input_path] || options[:procedure_input_path],
            result_payload: procedure_step[:result_payload],
            step_name: 'procedure'
          ),
          build_cleanup_target(
            resource_type: 'Encounter',
            source_input_path: options[:input_path],
            result_payload: encounter_result_payload,
            step_name: 'encounter'
          )
        ].compact
      end

      def build_cleanup_target(resource_type:, source_input_path:, result_payload:, step_name:)
        return nil unless successful_submission_result?(result_payload)

        reference_id = result_payload.dig('details', 'submission', 'reference_id')
        raise "#{resource_type} smoke did not produce submission.reference_id required for cleanup step" if blank?(reference_id)

        {
          resource_type:,
          reference_id:,
          source_input_path:,
          step_name:
        }
      end

      def successful_submission_result?(result_payload)
        return false unless result_payload.is_a?(Hash)
        return false unless result_payload['result_kind'] == 'success'

        !blank?(result_payload.dig('details', 'submission', 'reference_id'))
      end

      def run_cleanup_step(cleanup_target:, config_path:, run_dir:, debug_xml_dir:)
        input_payload = read_json_file(cleanup_target.fetch(:source_input_path))
        source_input_path = cleanup_target.fetch(:source_input_path)
        step_name = cleanup_target.fetch(:step_name)
        resource_type = cleanup_target.fetch(:resource_type)
        reference_id = cleanup_target.fetch(:reference_id)

        raise "#{step_name.capitalize} cleanup source file is invalid JSON: #{source_input_path}" if input_payload.nil?

        destroy_input_payload = build_destroy_input(
          input_payload:,
          resource_type:,
          reference_id:
        )
        destroy_input_path = File.join(run_dir, "#{step_name}-destroy-input.json")
        destroy_output_path = File.join(run_dir, "#{step_name}-destroy-result.json")

        write_json_file(destroy_input_path, destroy_input_payload)
        exit_code = run_once(config_path, destroy_input_path, destroy_output_path, debug_xml_dir)

        {
          ran: true,
          step_name:,
          resource_type:,
          reference_id:,
          exit_code:,
          source_input_path:,
          input_path: destroy_input_path,
          output_path: destroy_output_path,
          result_payload: read_json_file(destroy_output_path)
        }
      end

      def build_destroy_input(input_payload:, resource_type:, reference_id:)
        doctor_payload = deep_copy(input_payload.fetch('payload').fetch('doctor'))
        task_id = input_payload['task_id'] || input_payload.dig('payload', 'task_id') || 'live-smoke'

        {
          'task_id' => "#{task_id}-destroy-#{resource_type.downcase}",
          'operation_kind' => 'destroy_resource',
          'payload' => {
            'doctor' => doctor_payload,
            'resource' => {
              'resource_type' => resource_type,
              'resource_id' => reference_id
            }
          }
        }
      end

      def overall_exit_code(encounter_exit_code, *steps)
        return encounter_exit_code unless encounter_exit_code.zero?

        steps.each do |step|
          return step[:exit_code] if step[:ran] && !step[:exit_code].zero?
        end

        encounter_exit_code
      end

      def deep_copy(value)
        JSON.parse(JSON.generate(value))
      end

      def write_json_file(path, payload)
        File.write(path, JSON.pretty_generate(payload) + "\n")
      end

      def print_summary(config:, config_path:, input_path:, output_path:, run_dir:, debug_xml_dir:, exit_code:, audit_tail:, encounter_result_payload:, procedure_step:, condition_step:, provenance_step:, cleanup_steps:)
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
        print_condition_step_summary(config:, condition_step:, audit_tail:)
        print_provenance_step_summary(config:, provenance_step:, audit_tail:)
        print_cleanup_steps_summary(config:, cleanup_steps:, audit_tail:)
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

      def print_condition_step_summary(config:, condition_step:, audit_tail:)
        if condition_step[:skipped]
          @stdout.puts('Condition step: skipped because encounter step did not finish with success')
          return
        end
        return unless condition_step[:ran]

        result_payload = condition_step[:result_payload]
        transport_id = result_payload&.fetch('transport_id', nil)

        print_lines(
          "Condition input path: #{File.expand_path(condition_step[:input_path])}",
          "Condition resolved input path: #{condition_step[:resolved_input_path]}",
          "Condition result path: #{condition_step[:output_path]}",
          "Condition transport ID: #{transport_id || 'n/a'}",
          "Condition result kind: #{result_payload&.fetch('result_kind', nil) || 'n/a'}"
        )

        print_step_audit(
          title: 'Recent condition audit events:',
          path: config.dig(:paths, :audit_log),
          transport_id:,
          limit: audit_tail
        )
      end

      def print_provenance_step_summary(config:, provenance_step:, audit_tail:)
        if provenance_step[:skipped]
          @stdout.puts('Provenance step: skipped because prerequisite steps did not finish with success')
          return
        end
        return unless provenance_step[:ran]

        result_payload = provenance_step[:result_payload]
        transport_id = result_payload&.fetch('transport_id', nil)

        print_lines(
          "Provenance input path: #{File.expand_path(provenance_step[:input_path])}",
          "Provenance resolved input path: #{provenance_step[:resolved_input_path]}",
          "Provenance result path: #{provenance_step[:output_path]}",
          "Provenance transport ID: #{transport_id || 'n/a'}",
          "Provenance result kind: #{result_payload&.fetch('result_kind', nil) || 'n/a'}"
        )

        print_step_audit(
          title: 'Recent provenance audit events:',
          path: config.dig(:paths, :audit_log),
          transport_id:,
          limit: audit_tail
        )
      end

      def print_cleanup_steps_summary(config:, cleanup_steps:, audit_tail:)
        cleanup_steps.each do |cleanup_step|
          result_payload = cleanup_step[:result_payload]
          transport_id = result_payload&.fetch('transport_id', nil)
          step_name = cleanup_step.fetch(:step_name).capitalize

          print_lines(
            "#{step_name} cleanup input path: #{cleanup_step[:input_path]}",
            "#{step_name} cleanup result path: #{cleanup_step[:output_path]}",
            "#{step_name} cleanup transport ID: #{transport_id || 'n/a'}",
            "#{step_name} cleanup result kind: #{result_payload&.fetch('result_kind', nil) || 'n/a'}"
          )

          print_step_audit(
            title: "Recent #{cleanup_step.fetch(:step_name)} cleanup audit events:",
            path: config.dig(:paths, :audit_log),
            transport_id:,
            limit: audit_tail
          )
        end
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
