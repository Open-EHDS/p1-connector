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
              xml.security do
                xml.system(value: constants::SECURITY_SYSTEM)
                xml.code(value: constants::DEFAULT_SECURITY_CODE)
              end
            end
          end

          def encounter_class(xml)
            xml.class_ do
              xml.system(value: constants::ENCOUNTER_CLASS_SYSTEM)
              xml.code(value: data[:class_code])
              display(xml, data[:class_name])
            end
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
            xml.episodeOfCare do
              identifier(xml, system: data[:episode_identifier_system], value: data[:episode_identifier])
            end
          end

          def participant(xml)
            xml.participant do
              participant_function(xml)
              participant_individual(xml)
            end
          end

          def participant_function(xml)
            xml.extension(url: constants::PL_FUNCTION_EXTENSION) do
              xml.valueCoding do
                xml.system(value: constants::DOCTOR_PROFESSION_SYSTEM)
                xml.code(value: data[:doctor_profession_number])
              end
            end
          end

          def participant_individual(xml)
            xml.individual do
              identifier(xml, system: data[:doctor_identifier_system], value: data[:doctor_identifier_value])
              display(xml, data[:doctor_name])
            end
          end

          def period(xml)
            xml.period do
              xml.start(value: data[:start_time])
              xml.end(value: data[:end_time])
            end
          end

          def location(xml)
            xml.location do
              xml.location do
                identifier(xml, system: data[:location_identifier_system], value: data[:location_identifier_value])
              end
              xml.period do
                xml.start(value: data[:start_time])
                xml.end(value: data[:end_time])
              end
            end
          end

          def service_provider(xml)
            xml.serviceProvider do
              xml.extension(url: constants::PL_PAYOR_REFERENCE_EXTENSION) do
                xml.valueReference do
                  identifier(xml, system: data[:payer_identifier_system], value: data[:payer_identifier_value])
                end
              end
              identifier(xml, system: data[:provider_identifier_system], value: data[:provider_identifier_value])
            end
          end
        end
      end
    end
  end
end
