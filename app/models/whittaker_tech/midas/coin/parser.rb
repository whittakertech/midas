# frozen_string_literal: true

# Parser coerces heterogeneous inputs into a {Coin}.
#
# Accepted input types:
#
# | Type    | Behaviour                                                    |
# |---------|--------------------------------------------------------------|
# | {Coin}  | Returned as-is — no conversion.                              |
# | {Money} | Wraps `money.cents` + `money.currency.iso_code` into a Coin. |
# | Numeric | Treated as a **major-unit** amount; `currency_code` required. |
# | String  | Strips non-numeric characters; `currency_code` recommended.   |
#
# ### Numeric vs. Integer semantics
#
# The Parser treats all Numeric inputs (including Integer) as **major units**
# (dollars, euros, etc.) and scales them to minor units using
# `Money.from_amount`. This differs from {Coin#amount=} and {Coin.value},
# which expect minor units directly.
#
# If you already have cents use `Coin.value(2999, 'USD')` instead.
#
# @example
#   Coin.parse(Money.new(2999, 'USD'))          # => Coin(2999 USD)
#   Coin.parse(29.99, currency_code: 'USD')     # => Coin(2999 USD)
#   Coin.parse('$29.99')                        # => Coin(2999 USD)  (uses Money.default_currency)
#   Coin.parse('29.99', currency_code: 'USD')   # => Coin(2999 USD)
#
# @since 0.1.0
class WhittakerTech::Midas::Coin::Parser
  class << self
    # Parses a value into a {Coin}.
    #
    # @param value [Coin, Money, Numeric, String] the value to parse
    # @param currency_code [String, nil] required for bare Numeric and plain
    #   String values
    # @return [Coin]
    # @raise [TypeError] if `value` is an unsupported type
    # @raise [ArgumentError] if `currency_code` is required but not provided
    def parse(value, currency_code: nil)
      case value
      when WhittakerTech::Midas::Coin
        value
      when Money
        WhittakerTech::Midas::Coin.value(value.cents, value.currency.iso_code)
      when Numeric
        parse_numeric(value, currency_code)
      when String
        parse_string(value, currency_code)
      else
        raise TypeError, "Cannot convert #{value.class} to Coin"
      end
    end

    private

    # Converts a Numeric major-unit amount to a Coin.
    #
    # @param value [Numeric] major-unit amount (e.g. `29.99` for $29.99)
    # @param currency_code [String, nil]
    # @return [Coin]
    # @raise [ArgumentError] if `currency_code` is nil
    def parse_numeric(value, currency_code)
      raise ArgumentError, 'currency_code required' unless currency_code

      money = Money.from_amount(value, currency_code)
      WhittakerTech::Midas::Coin.value(money.cents, money.currency.iso_code)
    end

    # Converts a String amount to a Coin.
    #
    # If the string contains non-numeric, non-decimal characters (e.g. `$`)
    # and no `currency_code` is given, `Money.default_currency` is used.
    # A bare numeric string (e.g. `"29.99"`) without a `currency_code` raises.
    #
    # @param str [String]
    # @param currency_code [String, nil]
    # @return [Coin]
    # @raise [ArgumentError] if the string has no embedded currency marker and
    #   `currency_code` is nil
    def parse_string(str, currency_code)
      stripped = str.strip

      money =
        if currency_code
          Money.from_amount(extract_number(stripped), currency_code)
        elsif stripped =~ /[^\d.\s]/
          Money.from_amount(extract_number(stripped), Money.default_currency)
        else
          raise ArgumentError, 'Currency code required for string amounts'
        end

      WhittakerTech::Midas::Coin.value(money.cents, money.currency.iso_code)
    end

    # Strips all characters that are not digits or a decimal point.
    #
    # @param str [String]
    # @return [BigDecimal]
    def extract_number(str)
      BigDecimal(str.gsub(/[^\d.]/, ''))
    end
  end
end
