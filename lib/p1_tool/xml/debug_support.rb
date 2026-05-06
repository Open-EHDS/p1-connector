# frozen_string_literal: true

module P1Tool
  module Xml
    module DebugSupport
      private

      def persist_debug_xml(xml:, resource_name:, identifier:)
        return unless ENV['P1_DEBUG_XML'] == '1'

        file_system.atomic_write(debug_xml_path(resource_name:, identifier:), xml)
      end

      def debug_xml_path(resource_name:, identifier:)
        file_system.mkdir_p(debug_xml_dir)
        File.join(debug_xml_dir, "#{sanitize(resource_name)}.#{sanitize(identifier)}.xml")
      end

      def debug_xml_dir
        File.expand_path(ENV.fetch('P1_DEBUG_XML_PATH', './tmp/debug_xml'))
      end

      def sanitize(value)
        value.to_s.gsub(/[^a-zA-Z0-9._-]/, '_')
      end

      def file_system
        @file_system ||= P1Tool::Adapters::FileSystem.new
      end
    end
  end
end
