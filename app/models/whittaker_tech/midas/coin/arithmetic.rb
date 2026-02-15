# frozen_string_literal: true

# Arithmetic defines the arithmetic and equality semantics of a Coin.
#
# This module is intentionally:
# - immutable (all operations return new Coins)
# - closed under Coin (operations return Coin, not primitives)
# - policy-aware only where unavoidable (division)
#
# Formatting, presentation, and pricing interpretation do NOT live here.
module WhittakerTech::Midas::Coin::Arithmetic
  # Two Coins are equal if they represent the same currency
  # and the same minor-unit amount.
  #
  # @return [Boolean]
  def ==(other)
    other.is_a?(WhittakerTech::Midas::Coin) &&
      currency_code == other.currency_code &&
      currency_minor == other.currency_minor
  end

  alias eql? ==

  # Hash consistency for use in Sets, Hash keys, etc.
  def hash
    [currency_code, currency_minor].hash
  end

  # Adds two Coins together. Raises an error if the currencies do not match.
  #
  # This operation is exact and policy-free.
  #
  # @return [Coin]
  def +(other)
    ensure_same_currency!(other)
    WhittakerTech::Midas::Coin.value(currency_minor + other.currency_minor, currency_code).freeze
  end

  # Subtracts one Coin from another. Raises an error if the currencies do not match.
  #
  # This operation is exact and policy-free.
  #
  # @return [Coin]
  def -(other)
    ensure_same_currency!(other)
    WhittakerTech::Midas::Coin.value(currency_minor - other.currency_minor, currency_code).freeze
  end

  # Multiplies a Coin by a numeric value.
  #
  # This operation is exact and policy-free.
  #
  # @return [Coin]
  def *(other)
    raise TypeError unless other.is_a?(Integer)

    WhittakerTech::Midas::Coin.value(currency_minor * other, currency_code).freeze
  end

  # Returns the remainder Coin after dividing by an integer divisor.
  #
  # This operation is exact and policy-free.
  #
  # @return [Coin]
  def %(other)
    raise TypeError unless other.is_a?(Integer)
    raise ZeroDivisionError if other.zero?

    WhittakerTech::Midas::Coin.value(currency_minor % other, currency_code).freeze
  end

  # Reverses the sign of a Coin.
  #
  # @return [Coin]
  def negate
    WhittakerTech::Midas::Coin.value(-currency_minor, currency_code).freeze
  end

  # Unary negation: -coin
  def -@
    negate
  end

  # Divides a Coin by a numeric value.
  #
  # Raises TypeError if the divisor is not a numeric value.
  #
  # Raises ZeroDivisionError if the divisor is zero.
  #
  # Warns if the rounding policy is not recognized.
  # Accepted rounding policies are defined in Midas::ROUNDING_POLICIES.
  #
  # This operation is policy-aware.
  #
  # @return [Coin]
  def divide(divisor, rounding_policy: WhittakerTech::Midas::DEFAULT_ROUNDING_POLICY)
    raise TypeError unless divisor.is_a?(Numeric)
    raise ZeroDivisionError if divisor.zero?

    mode = WhittakerTech::Midas::ROUNDING_POLICIES[rounding_policy]

    unless mode
      warn "Unknown rounding mode: #{rounding_policy.inspect}. Using default rounding mode."
      mode = WhittakerTech::Midas::ROUNDING_POLICIES[
        WhittakerTech::Midas::DEFAULT_ROUNDING_POLICY
      ]
    end

    raw = currency_minor.to_f / divisor
    minor = mode.call(raw).to_i

    WhittakerTech::Midas::Coin.value(minor, currency_code).freeze
  end

  # Convenience helpers generated from the rounding policy dictionary.
  #
  # Example:
  #   coin.divide_ceil(10)
  #   coin.divide_floor(3)
  #
  # These methods exist for semantic clarity and readability.
  WhittakerTech::Midas::ROUNDING_POLICIES.each_key do |rounding_policy|
    method_name = :"divide_#{rounding_policy}"

    next if method_defined?(method_name)

    define_method(method_name) do |divisor|
      divide(divisor, rounding_policy: rounding_policy)
    end
  end

  private

  # Ensures arithmetic operations are only performed on compatible currencies.
  def ensure_same_currency!(other)
    raise TypeError unless other.is_a?(WhittakerTech::Midas::Coin)
    raise ArgumentError, 'Currencies must match' unless currency_code == other.currency_code
  end
end
