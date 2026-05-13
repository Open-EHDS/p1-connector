# frozen_string_literal: true

require_relative '../../../../test_helper'

describe P1Tool::Application::Integrations::P1::CreateOrUpdateSubmit do
  def recording_client
    Class.new do
      attr_reader :calls

      def initialize
        @calls = []
      end

      def create_resource(resource_type:, xml:)
        @calls << [:create, resource_type, xml]
        { status: 201, reference_id: "created-#{resource_type.downcase}", version_id: '1' }
      end

      def update_resource(resource_type:, reference_id:, xml:)
        @calls << [:update, resource_type, reference_id, xml]
        { status: 200, reference_id:, version_id: '2' }
      end
    end.new
  end

  it 'submits encounter through shared create/update flow while preserving constructor contract' do
    client = recording_client

    result = P1Tool::Application::Integrations::P1::Encounter::Submit.new(
      xml: '<Encounter/>',
      encounter_data: {},
      client:
    ).call

    assert_equal [[:create, 'Encounter', '<Encounter/>']], client.calls
    assert_equal 'created', result[:status]
    assert_equal 'submit_encounter_to_p1', result[:action]
    assert_equal 'created-encounter', result[:reference_id]
  end

  it 'submits provenance through shared update flow' do
    client = recording_client

    result = P1Tool::Application::Integrations::P1::Provenance::Submit.new(
      xml: '<Provenance/>',
      provenance_data: { resource_id: 'prov-1' },
      client:
    ).call

    assert_equal [[:update, 'Provenance', 'prov-1', '<Provenance/>']], client.calls
    assert_equal 'updated', result[:status]
    assert_equal 'submit_provenance_to_p1', result[:action]
    assert_equal 'prov-1', result[:reference_id]
  end
end
