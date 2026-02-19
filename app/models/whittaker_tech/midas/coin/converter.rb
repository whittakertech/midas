# frozen_string_literal: true

# Converter is a reserved module for future currency conversion logic.
#
# It exists as a clear architectural placeholder to separate concerns:
#
# | Module      | Responsibility                     |
# |-------------|------------------------------------|
# | {Arithmetic}| Integer arithmetic on minor units  |
# | {Allocation}| Per-unit pricing interpretation    |
# | Converter   | Cross-currency rate conversion *(planned)* |
#
# When implemented, Converter will handle:
# - Exchange rate sources (live API, snapshot, historical)
# - Historical conversions with a specific timestamp
# - Regulatory rounding rules per jurisdiction
#
# @note All methods in this module raise {NotImplementedError} intentionally.
#   Use the Money gem's exchange rate infrastructure directly for now.
# @since 0.1.0
module WhittakerTech::Midas::Coin::Converter
  # Converts this Coin to another currency.
  #
  # @param currency_code [String] target ISO 4217 currency code
  # @param at [Time] the rate timestamp (for historical conversions)
  # @param using [Object, nil] exchange rate provider / bank override
  # @return [Coin]
  # @raise [NotImplementedError] — not yet implemented
  def convert_to(currency_code, at: Time.current, using: nil)
    raise NotImplementedError
  end
end
