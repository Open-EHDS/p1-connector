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
    encounter_destroy_result_path = File.join(output_dir, 'encounter-destroy-result.json')

    assert_equal 0, exit_code
    assert_equal 'success', JSON.parse(File.read(result_path)).fetch('result_kind')
    assert_equal 'success', JSON.parse(File.read(encounter_destroy_result_path)).fetch('result_kind')
    assert_path_exists debug_xml_dir
    assert_includes stdout.string, 'Live smoke finished'
    assert_includes stdout.string, File.expand_path(result_path)
    assert_includes stdout.string, 'Encounter cleanup result path:'
    assert_includes stdout.string, 'Recent audit events:'
    assert_includes stdout.string, 'p1_encounter_submitted'
    assert_includes stdout.string, 'p1_resource_destroyed'
    assert_empty stderr.string
    assert_nil ENV.fetch('P1_DEBUG_XML', nil)
    assert_nil ENV.fetch('P1_DEBUG_XML_PATH', nil)
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

  it 'runs provenance smoke after successful prerequisite steps' do
    write_config_fixture(
      config_path,
      fixture_name: 'runtime_config.yml',
      replacements: { '__AUDIT_LOG_PATH__' => audit_log_path }
    )
    File.write(input_path, JSON.pretty_generate(fixture_json('runtime', 'register_encounter_input.json')))
    procedure_input_path = File.join(tmpdir, 'procedure-input.json')
    condition_input_path = File.join(tmpdir, 'condition-input.json')
    provenance_input_path = File.join(tmpdir, 'provenance-input.json')
    File.write(procedure_input_path, JSON.pretty_generate(fixture_json('runtime', 'register_procedure_input.json')))
    File.write(condition_input_path, JSON.pretty_generate(fixture_json('runtime', 'register_condition_input.json')))
    File.write(provenance_input_path, JSON.pretty_generate(fixture_json('runtime', 'register_provenance_input.json')))

    signature_client = Class.new do
      attr_reader :documents

      def generate_signature(documents:)
        @documents = documents
        {
          'document' => '<Signature/>',
          'documentBase64' => 'PFNpZ25hdHVyZS8+'
        }
      end
    end.new
    client = build_fake_p1_client
    client.instance_variable_set(:@destroy_calls, [])
    client.define_singleton_method(:destroy_calls) { @destroy_calls }
    client.define_singleton_method(:destroy_resource) do |resource_type:, reference_id:|
      @destroy_calls << [resource_type, reference_id]
      { status: 200, body: nil, headers: {} }
    end

    exit_code = with_stubbed_pkcs12_validation do
      with_fake_p1_client_factory(client) do
        with_singleton_stub(P1Tool::Gateways::SignatureService::Client, :new, ->(**_kwargs) { signature_client }) do
          P1Tool::Application::LiveSmokeRunner.start(
            [
              '--config', config_path,
              '--input', input_path,
              '--procedure-input', procedure_input_path,
              '--condition-input', condition_input_path,
              '--provenance-input', provenance_input_path,
              '--output-dir', output_dir,
              '--clean',
              '--audit-tail', '2'
            ],
            stdout: stdout,
            stderr: stderr
          )
        end
      end
    end

    provenance_result_path = File.join(output_dir, 'provenance-result.json')
    resolved_provenance_input_path = File.join(output_dir, 'provenance-input.resolved.json')
    resolved_references = JSON.parse(File.read(resolved_provenance_input_path)).fetch('payload').fetch('references')
    destroy_calls = client.destroy_calls

    assert_equal 0, exit_code
    assert_equal 'success', JSON.parse(File.read(provenance_result_path)).fetch('result_kind')
    assert_equal [
      { 'resource_type' => 'Patient', 'reference_id' => 'stub-patient-75061134485', 'version_id' => '7' },
      { 'resource_type' => 'Encounter', 'reference_id' => 'stub-encounter-1', 'version_id' => '1' },
      { 'resource_type' => 'Procedure', 'reference_id' => 'stub-procedure-1', 'version_id' => '1' },
      { 'resource_type' => 'Condition', 'reference_id' => 'stub-condition-1', 'version_id' => '1' }
    ], resolved_references
    assert_equal [
      {
        uri: 'https://isus.ezdrowie.gov.pl/fhir/Patient/stub-patient-75061134485/_history/7',
        mimeType: 'application/fhir+xml',
        content: '<Patient id="stub-patient-75061134485" version="7"/>'
      },
      {
        uri: 'https://isus.ezdrowie.gov.pl/fhir/Encounter/stub-encounter-1/_history/1',
        mimeType: 'application/fhir+xml',
        content: '<Encounter id="stub-encounter-1" version="1"/>'
      },
      {
        uri: 'https://isus.ezdrowie.gov.pl/fhir/Procedure/stub-procedure-1/_history/1',
        mimeType: 'application/fhir+xml',
        content: '<Procedure id="stub-procedure-1" version="1"/>'
      },
      {
        uri: 'https://isus.ezdrowie.gov.pl/fhir/Condition/stub-condition-1/_history/1',
        mimeType: 'application/fhir+xml',
        content: '<Condition id="stub-condition-1" version="1"/>'
      }
    ], signature_client.documents
    assert_equal [
      %w[Provenance stub-provenance-1],
      %w[Condition stub-condition-1],
      %w[Procedure stub-procedure-1],
      %w[Encounter stub-encounter-1]
    ], destroy_calls
    assert_includes stdout.string, 'Provenance result path:'
    assert_includes stdout.string, 'Provenance cleanup result path:'
    assert_includes stdout.string, 'Condition cleanup result path:'
    assert_includes stdout.string, 'Procedure cleanup result path:'
    assert_includes stdout.string, 'Encounter cleanup result path:'
    assert_includes stdout.string, 'p1_provenance_submitted'
    assert_empty stderr.string
  end
end
