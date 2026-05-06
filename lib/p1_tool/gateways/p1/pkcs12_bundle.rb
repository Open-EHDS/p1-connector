# frozen_string_literal: true

require 'openssl'

module P1Tool
  module Gateways
    module P1
      class Pkcs12Bundle
        attr_reader :certificate, :key, :ca_certs

        def self.load(path:, password:)
          new(path:, password:).load
        end

        def initialize(path:, password:)
          @path = File.expand_path(path)
          @password = password
        end

        def load
          OpenSSL::Provider.load('legacy')
          OpenSSL::Cipher.new('RC4')
          pkcs12 = OpenSSL::PKCS12.new(File.binread(path), password)

          self.class.allocate.tap do |bundle|
            bundle.instance_variable_set(:@certificate, pkcs12.certificate)
            bundle.instance_variable_set(:@key, pkcs12.key)
            bundle.instance_variable_set(:@ca_certs, pkcs12.ca_certs)
          end
        rescue Errno::ENOENT
          raise P1Tool::ConfigurationError, "Certificate file not found: #{path}"
        rescue OpenSSL::PKCS12::PKCS12Error => e
          raise P1Tool::ConfigurationError, "Cannot load certificate #{path}: #{e.message}"
        end

        private

        attr_reader :path, :password
      end
    end
  end
end
