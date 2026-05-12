# frozen_string_literal: true

module P1Tool
  module Application
    module ReferenceData
      module PLMedicalEventStaffRole
        DATA = {
          'LEK' => { label: 'Lekarz', medical_profession_code: '11' }.freeze,
          'FEL' => { label: 'Felczer', medical_profession_code: '5' }.freeze,
          'LEKD' => { label: 'Lekarz dentysta', medical_profession_code: '12' }.freeze,
          'PIEL' => { label: 'Pielegniarka/Pielegniarz', medical_profession_code: '18' }.freeze,
          'POL' => { label: 'Polozna/Polozny', medical_profession_code: '19' }.freeze,
          'FARM' => { label: 'Farmaceuta', medical_profession_code: '4' }.freeze,
          'RAT' => { label: 'Ratownik medyczny', medical_profession_code: '22' }.freeze,
          'PROF' => { label: 'Inny profesjonalista medyczny', medical_profession_code: nil }.freeze,
          'PADM' => { label: 'Pracownik administracyjny', medical_profession_code: nil }.freeze,
          'ASYS' => { label: 'Asystent medyczny', medical_profession_code: nil }.freeze,
          'FIZJO' => { label: 'Fizjoterapeuta', medical_profession_code: '6' }.freeze,
          'DIAG' => { label: 'Diagnosta laboratoryjny', medical_profession_code: '2' }.freeze,
          'HIGSZKOL' => { label: 'Higienistka szkolna', medical_profession_code: '8' }.freeze
        }.freeze

        class << self
          def all_codes = DATA.keys

          def fetch(code)
            DATA.fetch(code.to_s)
          end

          def include?(code)
            DATA.key?(code.to_s)
          end

          def mapped_medical_profession_code_for(code)
            fetch(code).fetch(:medical_profession_code)
          end
        end
      end
    end
  end
end
