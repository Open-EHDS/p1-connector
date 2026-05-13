# frozen_string_literal: true

module P1Tool
  module Application
    module ReferenceData
      class P1ElementCatalog
        DATA_FILE = File.expand_path('../../../../data/p1_procedure_elements.csv', __dir__)

        def initialize(path: DATA_FILE)
          @path = path
        end

        def fetch(code)
          index[code.to_s]
        end

        private

        attr_reader :path

        def index
          @index ||= load_index
        end

        def load_index
          headers, *rows = File.readlines(path, chomp: true)
          header_names = headers.to_s.split(';')

          rows.each_with_object({}) do |row, result|
            next if row.empty?

            entry = parse_entry(row, header_names)
            result[entry.fetch(:code)] = entry
          end
        end

        def parse_entry(row, header_names)
          values = row.split(';', header_names.length)
          entry = header_names.zip(values).to_h

          {
            code: entry.fetch('code'),
            system: "urn:oid:2.16.840.1.113883.3.4424.11.1.#{entry.fetch('system')}",
            display: entry.fetch('name')
          }
        end
      end
    end
  end
end
