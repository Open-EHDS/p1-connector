# frozen_string_literal: true

module P1Tool
  module Application
    module Operations
      module Support
        module ResolvesP1Client
          private

          def resolved_p1_client(validated_payload)
            @resolved_p1_client ||= p1_client || build_p1_client(validated_payload)
          end

          def build_p1_client(validated_payload)
            P1Tool::Gateways::P1::ClientFactory.build(
              config:,
              doctor: validated_payload.fetch(:doctor)
            )
          end
        end
      end
    end
  end
end
