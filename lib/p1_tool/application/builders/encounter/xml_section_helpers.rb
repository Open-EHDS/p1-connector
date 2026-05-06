# frozen_string_literal: true

module P1Tool
  module Application
    module Builders
      module Encounter
        module XmlSectionHelpers
          private

          def meta(xml)
            xml.meta do
              xml.profile(value: constants::PROFILE)
              xml.security { xml.system(value: constants::SECURITY_SYSTEM); xml.code(value: constants::DEFAULT_SECURITY_CODE) }
            end
          end

          def encounter_class(xml)
            xml.send(:class) { xml.system(value: constants::ENCOUNTER_CLASS_SYSTEM); xml.code(value: data[:class_code]); display(xml, data[:class_name]) }
          end

          def subject(xml)
            xml.subject do
              xml.reference(value: "Patient/#{data[:patient_reference_id]}")
              xml.type(value: 'Patient')
              identifier(xml, system: constants.patient_pesel_system, value: data[:patient_pesel])
              display(xml, data[:patient_name])
            end
          end

          def episode_of_care(xml)
            xml.episodeOfCare { identifier(xml, system: data[:episode_identifier_system], value: data[:episode_identifier]) }
          end

          def participant(xml)
            xml.participant do
              xml.extension(url: constants::PL_FUNCTION_EXTENSION) do
                xml.valueCoding { xml.system(value: constants::DOCTOR_PROFESSION_SYSTEM); xml.code(value: data[:doctor_profession_number]) }
              end
              xml.individual { identifier(xml, system: data[:doctor_identifier_system], value: data[:doctor_identifier_value]); display(xml, data[:doctor_name]) }
            end
          end

          def period(xml)
            xml.period { xml.start(value: data[:start_time]); xml.end(value: data[:end_time]) }
          end

          def location(xml)
            xml.location do
              xml.location { identifier(xml, system: data[:location_identifier_system], value: data[:location_identifier_value]) }
              xml.period { xml.start(value: data[:start_time]); xml.end(value: data[:end_time]) }
            end
          end

          def service_provider(xml)
            xml.serviceProvider do
              xml.extension(url: constants::PL_PAYOR_REFERENCE_EXTENSION) do
                xml.valueReference { identifier(xml, system: data[:payer_identifier_system], value: data[:payer_identifier_value]) }
              end
              identifier(xml, system: data[:provider_identifier_system], value: data[:provider_identifier_value])
            end
          end
        end
      end
    end
  end
end
