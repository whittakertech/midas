# frozen_string_literal: true

# Allocation represents a per-unit interpretation of a {Coin}.
#
# ## Conceptual model
#
# ```
# Coin       -> canonical, payable money (what exists)
# Allocation -> "this Coin, spread across N units, using policy X"
# ```
#
# An Allocation answers two questions:
#
# 1. **What does one unit cost?** — {#value}
# 2. **What does a given quantity cost?** — {#price}
#
# ## Immutability
#
# Allocation is:
# - **immutable** — `@coin`, `@divisor`, and `@rounding_policy` are frozen on
#   construction and never mutated.
# - **not persisted** — Allocation is a pure value object.
# - **minor-unit safe** — it never stores sub-minor-unit amounts; rounding is
#   applied before returning a Coin.
#
# @example Per-unit price from a bulk price
#   bulk = Coin.value(10_000, 'USD')  # $100.00 for a pack of 6
#   alloc = bulk.allocate(per: 6, rounding_policy: :ceil)
#   alloc.value          # => Coin($16.67)
#   alloc.price(qty: 2)  # => Coin($33.34)
#
# @see Coin#allocate
# @since 0.1.0
class WhittakerTech::Midas::Coin::Allocation
  # @return [Coin] the total monetary amount this Allocation is based on
  attr_reader :coin

  # @return [Numeric] the number of units the coin covers (the divisor)
  attr_reader :divisor

  # @return [Symbol] the rounding policy applied to per-unit calculations
  attr_reader :rounding_policy

  # Alias for {#divisor}. Reads as "this coin, per N units".
  alias per divisor

  # Delegate invariant facts from the underlying Coin.
  # These values do not change under scaling.
  delegate :currency_code,
           :currency,
           :decimals,
           :scale,
           :zero?,
           :positive?,
           :negative?,
           to: :coin

  # @param coin [Coin] the total monetary value
  # @param divisor [Numeric] the number of units; must be positive
  # @param rounding_policy [Symbol] one of {WhittakerTech::Midas::ROUNDING_POLICIES}
  # @raise [TypeError] if `coin` is not a {Coin}
  # @raise [TypeError] if `divisor` is not a positive Numeric
  # @raise [ArgumentError] if `rounding_policy` is not a recognised policy key
  def initialize(coin:, divisor:, rounding_policy:)
    raise TypeError unless coin.is_a?(WhittakerTech::Midas::Coin)
    raise TypeError unless divisor.is_a?(Numeric) && divisor.positive?
    raise ArgumentError unless WhittakerTech::Midas::ROUNDING_POLICIES.key?(rounding_policy)

    @coin = coin.freeze
    @divisor = divisor
    @rounding_policy = rounding_policy.freeze
  end

  # Returns the per-unit Coin after dividing by {#divisor} and applying the
  # {#rounding_policy}.
  #
  # The result is still a {Coin} — payable money representing a single unit.
  #
  # @return [Coin]
  def value
    coin.divide(divisor, rounding_policy: rounding_policy)
  end

  # Returns the total price for a given quantity of units.
  #
  # Uses `(total_minor * qty) / divisor` rounded via {#rounding_policy}.
  # Equivalent to `qty` units at the per-unit rate, but computed from the
  # original total to minimise accumulated rounding error.
  #
  # @param qty [Numeric] the number of units; must be >= 0
  # @return [Coin]
  # @raise [ArgumentError] if `qty` is negative or not Numeric
  #
  # @example
  #   alloc = Coin.value(10_000, 'USD').allocate(per: 6)
  #   alloc.price(qty: 3)   # => Coin($50.00)  (10000 * 3 / 6 = 5000 cents)
  def price(qty: 1)
    raise ArgumentError unless qty.is_a?(Numeric) && qty >= 0

    WhittakerTech::Midas::Coin.value(
      round((coin.currency_minor * qty) / divisor),
      coin.currency_code
    ).freeze
  end

  # Human-readable representation for logs and console output.
  # @return [String]
  def inspect
    "#<#{self.class.name} coin=#{coin.inspect} divisor=#{divisor} rounding_policy=#{rounding_policy}>"
  end

  private

  # Applies the configured {#rounding_policy} to a raw Numeric amount and
  # returns an Integer suitable for Coin construction.
  # @param amount [Numeric]
  # @return [Integer]
  def round(amount)
    WhittakerTech::Midas::ROUNDING_POLICIES
      .fetch(rounding_policy)
      .call(amount)
      .to_i
  end
end
