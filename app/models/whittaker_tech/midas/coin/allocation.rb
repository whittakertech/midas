# frozen_string_literal: true

# Allocation represents a scaled interpretation of a Coin.
#
# Conceptually:
#   Coin   -> canonical, payable money
#   Allocation   -> "this Coin, per N units, using policy X"
#
# A Allocation:
# - is immutable
# - is not persisted
# - Never stores sub-minor currency
# - Always resolves back to a Coin via #value or #price
#
# Allocation is NOT mixed into Coin - it is constructed explicitly.
class WhittakerTech::Midas::Coin::Allocation
  attr_reader :coin, :divisor, :rounding_policy
  alias per divisor

  # Delegate invariant, scalar facts from the underlying Coin.
  # These do not change under scaling.
  delegate :currency_code,
           :currency,
           :decimals,
           :scale,
           :zero?,
           :positive?,
           :negative?,
           to: :coin

  def initialize(coin:, divisor:, rounding_policy:)
    raise TypeError unless coin.is_a?(WhittakerTech::Midas::Coin)
    raise TypeError unless divisor.is_a?(Numeric) && divisor.positive?
    raise ArgumentError unless WhittakerTech::Midas::ROUNDING_POLICIES.key?(rounding_policy)

    @coin = coin.freeze
    @divisor = divisor
    @rounding_policy = rounding_policy.freeze
  end

  # Returns the per-unit Coin after applying divisor and rounding policy
  #
  # This is still payable money (a Coin), but represents one unit.
  #
  # @return [Coin]
  def value
    coin.divide(divisor, rounding_policy: rounding_policy)
  end

  # Returns the total price for a given quantity of units.
  #
  # @return [Coin]
  def price(qty: 1)
    raise ArgumentError unless qty.is_a?(Numeric) && qty >= 0

    WhittakerTech::Midas::Coin.value(
      round((coin.currency_minor * qty) / divisor),
      coin.currency_code
    ).freeze
  end

  # Helpful inspection for logs and console usage.
  def inspect
    "#<#{self.class.name} coin=#{coin.inspect} divisor=#{divisor} rounding_policy=#{rounding_policy}>"
  end

  private

  def round(amount)
    WhittakerTech::Midas::ROUNDING_POLICIES
      .fetch(rounding_policy)
      .call(amount)
      .to_i
  end
end
