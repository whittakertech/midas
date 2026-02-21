# frozen_string_literal: true

# Arithmetic defines the arithmetic and equality semantics of a Coin.
#
# ## Design invariants
#
# - **Immutable** — all operations return new, frozen {Coin} objects.
# - **Closed** — operations always return a {Coin}, never a primitive.
# - **Policy-aware only where unavoidable** — division accepts a rounding
#   policy; all other operations are exact.
# - **Currency-strict** — binary operations (`+`, `-`, `==`) raise
#   {ArgumentError} when the operands have different currency codes.
#
# ## Convenience division helpers
#
# For each key in {WhittakerTech::Midas::ROUNDING_POLICIES} a named shorthand
# is generated:
#
#   coin.divide_round(3)   # same as coin.divide(3, rounding_policy: :round)
#   coin.divide_ceil(3)
#   coin.divide_floor(3)
#   coin.divide_bankers(3)
#
# @since 0.1.0
module WhittakerTech::Midas::Coin::Arithmetic
  # Tests value equality with another Coin.
  #
  # Two Coins are equal when they have the same currency code **and** the
  # same minor-unit amount. A Coin is never equal to a non-Coin object.
  #
  # @param other [Object] the object to compare
  # @return [Boolean]
  def ==(other)
    other.is_a?(WhittakerTech::Midas::Coin) &&
      currency_code == other.currency_code &&
      currency_minor == other.currency_minor
  end

  # Value-based equality alias, compatible with {#hash}.
  #
  # Suitable for use in Sets and as Hash keys.
  # @param other [Object]
  # @return [Boolean]
  alias eql? ==

  # Returns a hash value consistent with {#eql?}.
  #
  # Coins with the same currency code and minor-unit amount produce the same
  # hash, making them interchangeable as Hash keys or Set members.
  #
  # @return [Integer]
  def hash
    [currency_code, currency_minor].hash
  end

  # Adds two Coins and returns the sum as a new Coin.
  #
  # @param other [Coin] must have the same currency code as the receiver
  # @return [Coin] a new, frozen Coin
  # @raise [TypeError] if `other` is not a {Coin}
  # @raise [ArgumentError] if the currencies do not match
  #
  # @example
  #   a = Coin.value(1000, 'USD')
  #   b = Coin.value(500,  'USD')
  #   a + b  # => Coin($15.00)
  def +(other)
    ensure_same_currency!(other)
    WhittakerTech::Midas::Coin.value(currency_minor + other.currency_minor, currency_code).freeze
  end

  # Subtracts another Coin from the receiver and returns the difference.
  #
  # @param other [Coin] must have the same currency code as the receiver
  # @return [Coin] a new, frozen Coin
  # @raise [TypeError] if `other` is not a {Coin}
  # @raise [ArgumentError] if the currencies do not match
  #
  # @example
  #   a = Coin.value(1000, 'USD')
  #   b = Coin.value(300,  'USD')
  #   a - b  # => Coin($7.00)
  def -(other)
    ensure_same_currency!(other)
    WhittakerTech::Midas::Coin.value(currency_minor - other.currency_minor, currency_code).freeze
  end

  # Multiplies the Coin by an integer scalar.
  #
  # @param other [Integer] the multiplier
  # @return [Coin] a new, frozen Coin
  # @raise [TypeError] if `other` is not an Integer
  #
  # @example
  #   Coin.value(500, 'USD') * 3  # => Coin($15.00)
  def *(other)
    raise TypeError unless other.is_a?(Integer)

    WhittakerTech::Midas::Coin.value(currency_minor * other, currency_code).freeze
  end

  # Returns the remainder after dividing by an integer.
  #
  # @param other [Integer] the divisor
  # @return [Coin] a new, frozen Coin representing the remainder
  # @raise [TypeError] if `other` is not an Integer
  # @raise [ZeroDivisionError] if `other` is zero
  #
  # @example
  #   Coin.value(1001, 'USD') % 3  # => Coin($0.02)  (1001 % 3 == 2 cents)
  def %(other)
    raise TypeError unless other.is_a?(Integer)
    raise ZeroDivisionError if other.zero?

    WhittakerTech::Midas::Coin.value(currency_minor % other, currency_code).freeze
  end

  # Returns a new Coin with the sign reversed.
  #
  # @return [Coin] a new, frozen Coin
  #
  # @example
  #   Coin.value(500, 'USD').negate  # => Coin(-$5.00)
  def negate
    WhittakerTech::Midas::Coin.value(-currency_minor, currency_code).freeze
  end

  # Unary minus operator — shorthand for {#negate}.
  #
  # @return [Coin]
  def -@
    negate
  end

  # Divides the Coin by a numeric divisor and returns the quotient.
  #
  # Division is the only arithmetic operation that requires a rounding policy
  # because dividing integer minor units can produce a non-integer result.
  #
  # @param divisor [Numeric] the divisor; must be non-zero
  # @param rounding_policy [Symbol] one of the keys in
  #   {WhittakerTech::Midas::ROUNDING_POLICIES} (default:
  #   {WhittakerTech::Midas::DEFAULT_ROUNDING_POLICY})
  # @return [Coin] a new, frozen Coin
  # @raise [TypeError] if `divisor` is not Numeric
  # @raise [ZeroDivisionError] if `divisor` is zero
  #
  # @example
  #   Coin.value(1000, 'USD').divide(3, rounding_policy: :ceil)   # => Coin($3.34)
  #   Coin.value(1000, 'USD').divide(3, rounding_policy: :floor)  # => Coin($3.33)
  #   Coin.value(1000, 'USD').divide(3, rounding_policy: :bankers)# => Coin($3.33)
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

  # Raises if `other` is not a {Coin} with the same currency code.
  # @param other [Object]
  # @raise [TypeError] if `other` is not a Coin
  # @raise [ArgumentError] if currencies differ
  def ensure_same_currency!(other)
    raise TypeError unless other.is_a?(WhittakerTech::Midas::Coin)
    raise ArgumentError, 'Currencies must match' unless currency_code == other.currency_code
  end
end
