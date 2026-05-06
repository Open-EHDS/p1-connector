# frozen_string_literal: true

module P1Tool
  module Xml
    module BuilderHelpers
      private

      def resource_id(xml, value)
        return if blank?(value)

        xml.id(value:)
      end

      def identifier(xml, system:, value:)
        xml.identifier { xml.system(value: system); xml.value(value:) }
      end

      def display(xml, value)
        node = Nokogiri::XML::Node.new('display', xml.doc)
        node['value'] = value
        xml.parent.add_child(node)
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end
    end
  end
end
