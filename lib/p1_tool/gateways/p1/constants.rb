# frozen_string_literal: true

module P1Tool
  module Gateways
    module P1
      module Constants
        PESEL_SYSTEM = 'urn:oid:2.16.840.1.113883.3.4424.1.1.616'
        DOCTOR_NPWZ_SYSTEM = '2.16.840.1.113883.3.4424.1.6.2'
        ENTITY_SYSTEM = '2.16.840.1.113883.3.4424.2.3.1'
        PRACTICE_SYSTEM_PREFIX = '2.16.840.1.113883.3.4424.2.4.'
        ENTITY_LOCATION_UNIT_SYSTEM = '2.16.840.1.113883.3.4424.2.3.2'
        ENTITY_LOCATION_CELL_SYSTEM = '2.16.840.1.113883.3.4424.2.3.3'
        FHIR_SCOPE = 'https://ezdrowie.gov.pl/fhir'
        TOKEN_AUDIENCE = 'https://ezdrowie.gov.pl/token'

        ENVIRONMENTS = {
          'integration' => { base_url: 'https://isus.ezdrowie.gov.pl' },
          'production' => { base_url: 'https://sus.ezdrowie.gov.pl' }
        }.freeze

        module_function

        def environment!(name)
          ENVIRONMENTS.fetch(name) do
            raise P1Tool::ConfigurationError, "Unsupported P1 environment: #{name}"
          end
        end
      end
    end
  end
end
