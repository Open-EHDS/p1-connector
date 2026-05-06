# frozen_string_literal: true

module P1Tool
  module Gateways
    module P1
      class Client
        def create_resource(resource_type:, xml:)
          raise NotImplementedError, "P1 create_resource is not implemented for #{resource_type}"
        end

        def update_resource(resource_type:, reference_id:, xml:)
          raise NotImplementedError, "P1 update_resource is not implemented for #{resource_type} #{reference_id}"
        end

        def get_resource(resource_type:, reference_id:)
          raise NotImplementedError, "P1 get_resource is not implemented for #{resource_type} #{reference_id}"
        end

        def find_patient(payload:)
          raise NotImplementedError, "P1 find_patient is not implemented for #{payload.inspect}"
        end
      end
    end
  end
end
