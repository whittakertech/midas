# frozen_string_literal: true

module WhittakerTech
  module Midas
    class Coin
      # Converter is a placeholder for future currency conversion logic.
      #
      # This module is intentionally empty for now.
      # It exists to clearly separate:
      # - value arithmetic (Coin::Arithmetic)
      # - pricing interpretation (Coin::Allocation)
      # - currency conversion (Coin::Converter)
      #
      # Converter will eventually handle:
      # - exchange rate sources
      # - historical conversions
      # - regulatory rounding rules
      module Converter
        # Converts this Coin to another currency.
        #
        # @return [Coin]
        # Not implemented yet by design.
        def convert_to(currency_code, at: Time.current, using: nil)
          raise NotImplementedError
        end
      end
    end
  end
end
