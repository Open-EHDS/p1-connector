# frozen_string_literal: true

module P1Tool
  module Application
    module ReferenceData
      module PLMedicalProfession
        DATA = {
          '1' => { label: 'Asystentka dentystyczna' }.freeze,
          '2' => { label: 'Diagnosta laboratoryjny' }.freeze,
          '3' => { label: 'Dietetyk' }.freeze,
          '4' => { label: 'Farmaceuta' }.freeze,
          '5' => { label: 'Felczer' }.freeze,
          '6' => { label: 'Fizjoterapeuta' }.freeze,
          '7' => { label: 'Higienistka dentystyczna' }.freeze,
          '8' => { label: 'Higienistka szkolna' }.freeze,
          '9' => { label: 'Instruktor higieny' }.freeze,
          '11' => { label: 'Lekarz' }.freeze,
          '12' => { label: 'Lekarz dentysta' }.freeze,
          '13' => { label: 'Logopeda' }.freeze,
          '14' => { label: 'Masazysta' }.freeze,
          '15' => { label: 'Opiekunka dziecieca' }.freeze,
          '16' => { label: 'Optometrysta' }.freeze,
          '17' => { label: 'Ortoptystka' }.freeze,
          '18' => { label: 'Pielegniarka' }.freeze,
          '19' => { label: 'Polozna' }.freeze,
          '20' => { label: 'Protetyk sluchu' }.freeze,
          '21' => { label: 'Psychoterapeuta' }.freeze,
          '22' => { label: 'Ratownik medyczny' }.freeze,
          '23' => { label: 'Specjalista zdrowia publicznego' }.freeze,
          '24' => { label: 'Technik analityki medycznej' }.freeze,
          '25' => { label: 'Technik dentystyczny' }.freeze,
          '26' => { label: 'Technik farmaceutyczny' }.freeze,
          '27' => { label: 'Technik elektroniki medycznej' }.freeze,
          '28' => { label: 'Technik elektroradiolog' }.freeze,
          '29' => { label: 'Technik optyk' }.freeze,
          '30' => { label: 'Technik ortopeda' }.freeze,
          '31' => { label: 'Terapeuta zajeciowy' }.freeze,
          '32' => { label: 'Opiekun medyczny' }.freeze,
          '33' => { label: 'Instruktor terapii uzaleznien' }.freeze,
          '34' => { label: 'Specjalista psychoterapii uzaleznien' }.freeze,
          '35' => { label: 'Pedagog specjalny' }.freeze,
          '36' => { label: 'Terapeuta srodowiskowy' }.freeze,
          '37' => { label: 'Pedagog' }.freeze,
          '38' => { label: 'Psychoterapeuta dzieci i mlodziezy' }.freeze,
          '39' => { label: 'Profilaktyk' }.freeze,
          '50' => { label: 'Psycholog' }.freeze
        }.freeze

        class << self
          def include?(code)
            DATA.key?(code.to_s)
          end

          def fetch(code)
            DATA.fetch(code.to_s)
          end

          def codes
            DATA.keys
          end
        end
      end
    end
  end
end
