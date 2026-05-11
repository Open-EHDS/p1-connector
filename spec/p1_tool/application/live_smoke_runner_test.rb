# frozen_string_literal: true

require_relative '../../test_helper'

describe P1Tool::Application::LiveSmokeRunner do
  let(:tmpdir) { Dir.mktmpdir }
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:config_path) { File.join(tmpdir, 'config.yml') }
  let(:input_path) { File.join(tmpdir, 'input.json') }
  let(:output_dir) { File.join(tmpdir, 'live-smoke') }
  let(:audit_log_path) { File.join(tmpdir, 'audit', 'audit.jsonl') }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  it 'runs manual smoke flow and prints artifact summary' do
    write_config_fixture(
      config_path,
      fixture_name: 'runtime_config.yml',
      replacements: { '__AUDIT_LOG_PATH__' => audit_log_path }
    )
    File.write(input_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))

    exit_code = with_stubbed_pkcs12_validation do
      with_fake_p1_client_factory do
        P1Tool::Application::LiveSmokeRunner.start(
          ['--config', config_path, '--input', input_path, '--output-dir', output_dir, '--clean', '--audit-tail', '2'],
          stdout: stdout,
          stderr: stderr
        )
      end
    end

    result_path = File.join(output_dir, 'result.json')
    debug_xml_dir = File.join(output_dir, 'debug_xml')

    assert_equal 0, exit_code
    assert_equal 'success', JSON.parse(File.read(result_path)).fetch('result_kind')
    assert_path_exists debug_xml_dir
    assert_includes stdout.string, 'Live smoke finished'
    assert_includes stdout.string, File.expand_path(result_path)
    assert_includes stdout.string, 'Recent audit events:'
    assert_includes stdout.string, 'p1_encounter_submitted'
    assert_empty stderr.string
    assert_nil ENV['P1_DEBUG_XML']
    assert_nil ENV['P1_DEBUG_XML_PATH']
  end

  it 'runs procedure smoke after successful encounter smoke' do
    write_config_fixture(
      config_path,
      fixture_name: 'runtime_config.yml',
      replacements: { '__AUDIT_LOG_PATH__' => audit_log_path }
    )
    File.write(input_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))
    procedure_input_path = File.join(tmpdir, 'procedure-input.json')
    File.write(procedure_input_path, JSON.pretty_generate(fixture_json('runtime', 'register_procedure_input.json')))

    exit_code = with_stubbed_pkcs12_validation do
      with_fake_p1_client_factory do
        P1Tool::Application::LiveSmokeRunner.start(
          [
            '--config', config_path,
            '--input', input_path,
            '--procedure-input', procedure_input_path,
            '--output-dir', output_dir,
            '--clean',
            '--audit-tail', '2'
          ],
          stdout: stdout,
          stderr: stderr
        )
      end
    end

    procedure_result_path = File.join(output_dir, 'procedure-result.json')
    resolved_procedure_input_path = File.join(output_dir, 'procedure-input.resolved.json')

    assert_equal 0, exit_code
    assert_equal 'success', JSON.parse(File.read(procedure_result_path)).fetch('result_kind')
    assert_equal 'stub-encounter-1',
                 JSON.parse(File.read(resolved_procedure_input_path)).dig('payload', 'encounter', 'resource_id')
    assert_includes stdout.string, 'Procedure result path:'
    assert_includes stdout.string, 'p1_procedure_submitted'
    assert_empty stderr.string
  end

  it 'runs condition smoke after successful encounter smoke' do
    write_config_fixture(
      config_path,
      fixture_name: 'runtime_config.yml',
      replacements: { '__AUDIT_LOG_PATH__' => audit_log_path }
    )
    File.write(input_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))
    condition_input_path = File.join(tmpdir, 'condition-input.json')
    File.write(condition_input_path, JSON.pretty_generate(fixture_json('runtime', 'register_condition_input.json')))

    exit_code = with_stubbed_pkcs12_validation do
      with_fake_p1_client_factory do
        P1Tool::Application::LiveSmokeRunner.start(
          [
            '--config', config_path,
            '--input', input_path,
            '--condition-input', condition_input_path,
            '--output-dir', output_dir,
            '--clean',
            '--audit-tail', '2'
          ],
          stdout: stdout,
          stderr: stderr
        )
      end
    end

    condition_result_path = File.join(output_dir, 'condition-result.json')
    resolved_condition_input_path = File.join(output_dir, 'condition-input.resolved.json')

    assert_equal 0, exit_code
    assert_equal 'success', JSON.parse(File.read(condition_result_path)).fetch('result_kind')
    assert_equal 'stub-encounter-1',
                 JSON.parse(File.read(resolved_condition_input_path)).dig('payload', 'encounter', 'resource_id')
    assert_includes stdout.string, 'Condition result path:'
    assert_includes stdout.string, 'p1_condition_submitted'
    assert_empty stderr.string
  end
end
