# frozen_string_literal: true

module P1Tool
  module Application
    module ReferenceData
      module PLMedicalEventClass
        # Source:
        # https://isap.sejm.gov.pl/isap.nsf/download.xsp/WDU20190002532/O/D20192532.pdf
        DATA = {
          '1' => { code: '1', display: 'Pobyt w oddziale szpitalnym' }.freeze,
          '2' => { code: '2', display: 'Leczenie jednego dnia' }.freeze,
          '3' => { code: '3', display: 'Pobyt' }.freeze,
          '4' => { code: '4', display: 'Porada' }.freeze,
          '5' => { code: '5', display: 'Porada patronazowa' }.freeze,
          '6' => { code: '6', display: 'Wizyta' }.freeze,
          '7' => { code: '7', display: 'Wizyta patronazowa' }.freeze,
          '8' => { code: '8', display: 'Cykl leczenia' }.freeze,
          '9' => { code: '9', display: 'Badanie' }.freeze,
          '10' => { code: '10', display: 'Sesja' }.freeze,
          '11' => { code: '11', display: 'Osoba leczona' }.freeze,
          '12' => { code: '12', display: 'Wyjazd ratowniczy' }.freeze,
          '13' => { code: '13', display: 'Akcja ratownicza' }.freeze,
          '14' => { code: '14', display: 'Transport sanitarny' }.freeze,
          '15' => { code: '15', display: 'Transport lotniczy' }.freeze,
          '16' => { code: '16', display: 'Hemodializa' }.freeze,
          '17' => { code: '17', display: 'Bilans zdrowia' }.freeze,
          '18' => { code: '18', display: 'Wyrob medyczny' }.freeze,
          '19' => { code: '19', display: 'Szczepienie' }.freeze,
          '20' => { code: '20', display: 'Badanie (test) przesiewowe' }.freeze,
          '21' => { code: '21', display: 'Swiadczenie profilaktyczne' }.freeze,
          '22' => { code: '22', display: 'Osoba objeta opieka koordynowana' }.freeze
        }.freeze

        class << self
          def codes
            DATA.keys
          end

          def fetch(code)
            DATA.fetch(code.to_s)
          end

          def include?(code)
            DATA.key?(code.to_s)
          end

          def display_for(code)
            fetch(code).fetch(:display)
          end
        end
      end
    end
  end
end
