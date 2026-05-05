# frozen_string_literal: true

module P1Tool
  module EnvLoader
    module_function

    def load!(path: default_path)
      return false if @loaded
      return false unless File.file?(path)

      File.foreach(path) do |line|
        entry = parse_entry(line)
        next unless entry

        key, value = entry
        ENV[key] = value unless ENV.key?(key)
      end

      @loaded = true
    end

    def default_path
      File.expand_path('../../.env', __dir__)
    end

    def parse_entry(line)
      stripped = line.strip
      return if stripped.empty? || stripped.start_with?('#')

      stripped = stripped.delete_prefix('export ').strip
      key, value = stripped.split('=', 2)
      return if key.nil? || value.nil?

      [key.strip, unquote(value.strip)]
    end

    def unquote(value)
      double_quoted_match = value.match(/\A"(.*)"\z/)
      return double_quoted_match[1] if double_quoted_match

      single_quoted_match = value.match(/\A'(.*)'\z/)
      return single_quoted_match[1] if single_quoted_match

      value
    end
  end
end
