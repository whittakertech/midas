# frozen_string_literal: true

# Coin is the canonical, persisted representation of a monetary value.
#
# ## Conceptual model
#
# - A Coin represents *payable money*: an exact integer count of minor units
#   (cents, pence, etc.) in a specific currency.
# - A Coin is **immutable by convention**: arithmetic operations return new
#   frozen Coins rather than mutating the receiver.
# - A Coin owns **arithmetic truth** — not presentation, pricing
#   interpretation, or currency conversion.
# ## Storage
#
#
# Every Coin is persisted in `midas_coins` and belongs polymorphically to
# any domain object (`resource_type` / `resource_id`). The `resource_role`
# distinguishes multiple coins on the same resource (e.g. `"price"`,
# `"cost"`, `"tax"`).
#
# ## Modules
#
# Behavior is composed via mixins:
#
# | Module        | Responsibility                              |
# |---------------|---------------------------------------------|
# | {Arithmetic}  | `+`, `-`, `*`, `/`, `%`, `negate`, equality |
# | {Bidi}        | Unicode bidirectional text isolation        |
# | {Converter}   | Currency conversion (reserved, not yet live) |
# | {Presenter}   | Token-based formatting grammar              |
#
# ## Usage via {Bankable}
#
# The typical entry point is the {Bankable} concern; direct Coin construction
# is mostly used in service objects and tests.
#
#   product.set_price(amount: 29.99, currency_code: 'USD')
#   product.price         # => #<WhittakerTech::Midas::Coin ...>
#   product.price_amount  # => #<Money @fractional=2999 @currency="USD">
#
# @see Bankable
# @see Coin::Arithmetic
# @see Coin::Allocation
# @since 0.1.0
# rubocop:disable Metrics/ClassLength
class WhittakerTech::Midas::Coin < WhittakerTech::Midas::ApplicationRecord
  # Arithmetic: exact arithmetic and equality semantics
  include Arithmetic
  # Bidi: bidirectional currency conversion
  include Bidi
  # Converter: future currency conversion logic
  include Converter
  # Presenter: formatting and presentation logic
  include Presenter

  self.table_name = WhittakerTech::Midas.table_name('coins')

  # Coins belong polymorphically to a domain object (ledger, entry, product, etc.)
  belongs_to :resource, polymorphic: true

  # Poly::Joins defines joins_resource(klass) for typed polymorphic joins
  include Poly::Joins
  # Poly::Role validates resource_role, normalizes it, and provides for_role scope
  include Poly::Role
  # Poly::Owners defines owner_resource(klass) for typed polymorphic ownership
  include Poly::Owners

  # Normalize user input before validation to ensure consistent storage
  before_validation :normalize_currency_code

  # Delegates presence, format `/\A[a-z0-9_]+\z/`, length (max 64), and
  # before_validation normalization to Poly::Role
  poly_role :resource

  # Each resource may only have one Coin per resource_role
  validates :resource_role,
            uniqueness: { scope: %i[resource_type resource_id], case_sensitive: false }

  # Currency code is stored as a 3-letter ISO string (e.g. "USD")
  validates :currency_code,  presence: true, length: { is: 3 }

  # Minor units are always stored as integers
  validates :currency_minor, presence: true, numericality: { only_integer: true }

  # Returns a Money object representing the stored monetary value.
  #
  # This is a *projection*, not canonical value. Use {#currency_minor}
  # and {#currency_code} as the source of truth.
  #
  # Memoized for performance. The memo is cleared automatically when
  # {#currency_minor=} or {#currency_code=} are called.
  #
  # @return [Money]
  def amount
    @amount ||= Money.new(currency_minor, currency_code)
  end

  # Sets the coin's monetary value from a Money object or raw minor-unit integer.
  #
  # @param value [Money, Integer, Numeric] the value to assign
  #   - {Money} — copies `cents` and `currency.iso_code` directly.
  #   - {Numeric} — treated as already-scaled minor units; requires
  #     {#currency_code} to already be set.
  # @raise [ArgumentError] if a Numeric is given without a prior currency_code
  # @raise [ArgumentError] if the value type is not supported
  # @return [void]
  def amount=(value)
    case value
    when Money
      self.currency_minor = value.cents
      self.currency_code = value.currency.iso_code
    when Numeric
      raise ArgumentError, 'currency_code required before setting numeric amount' if currency_code.blank?

      self.currency_minor = Integer(value)
    else
      raise ArgumentError, "Invalid value for Coin#amount: #{value.inspect}"
    end
  end

  # Formats the Coin for display, optionally converting to another currency first.
  #
  # This is a convenience wrapper around the Money gem's `#format`. For
  # richer formatting use {#present} with a pattern string.
  #
  # @param to [String, nil] target ISO 4217 currency code for conversion,
  #   or `nil` to format in the native currency.
  # @return [String] the formatted monetary string, e.g. `"$29.99"`
  def format(to: nil)
    (to ? exchange_to(to) : amount).format
  end

  # @return [Integer] the raw minor-unit count (alias for {#currency_minor})
  def minor
    currency_minor
  end

  # @return [String] the ISO currency code (alias for {#currency_code})
  def currency
    currency_code
  end

  # @return [Integer] the raw minor-unit count (alias for {#currency_minor})
  def fractional
    currency_minor
  end

  # Clears the memoized Money projection when the minor-unit value changes.
  # @param value [Integer]
  # @return [void]
  def currency_minor=(value)
    @amount = nil
    super
  end

  # Clears the memoized Money projection when the currency code changes.
  # @param value [String]
  # @return [void]
  def currency_code=(value)
    @amount = nil
    super
  end

  # Constructs an {Coin::Allocation} that interprets this Coin as a per-unit price.
  #
  # The Coin itself is unchanged; {Coin::Allocation} encapsulates the
  # per-unit interpretation and rounding policy.
  #
  # @param per [Numeric] number of units this Coin covers (the divisor)
  # @param rounding_policy [Symbol] one of {WhittakerTech::Midas::ROUNDING_POLICIES}
  # @return [Coin::Allocation]
  #
  # @example Price per item from a bulk price
  #   bulk = Coin.value(10_000, 'USD')  # $100.00 for 6 units
  #   alloc = bulk.allocate(per: 6, rounding_policy: :ceil)
  #   alloc.value          # => Coin($16.67)
  #   alloc.price(qty: 3)  # => Coin($50.00)
  def allocate(per:, rounding_policy: WhittakerTech::Midas::DEFAULT_ROUNDING_POLICY)
    WhittakerTech::Midas::Coin::Allocation.new(
      coin: self,
      divisor: per,
      rounding_policy:
    )
  end

  # Returns the number of decimal places defined by the currency specification.
  #
  # For example, USD = 2, JPY = 0, BHD = 3
  # This is informational and does not imply rounding or formatting.
  #
  # @return [Integer]
  def decimals
    Money::Currency.new(currency_code).decimal_places
  end

  # Returns the scaling factor used to convert major units to minor units.
  #
  # Equivalent to `10 ** decimals`. For USD this is `100`; for JPY it is `1`.
  #
  # @return [Numeric]
  def scale
    10**decimals
  end

  # Returns the major-unit value as a precise BigDecimal.
  #
  # **This is NOT payable money.** It is intended for inspection and
  # formatting only. No rounding policy is applied.
  #
  # @return [BigDecimal]
  #
  # @example
  #   Coin.value(2999, 'USD').major  # => BigDecimal("29.99")
  #   Coin.value(100, 'JPY').major   # => BigDecimal("100")
  def major
    BigDecimal(currency_minor) / scale
  end

  class << self
    # Constructs a Coin directly from an integer minor-unit count and an ISO
    # currency code.
    #
    # This is the lowest-level factory. It enforces that `currency_minor` is
    # an Integer (fractional minor units are not permitted).
    #
    # @param currency_minor [Integer] the amount in minor units (e.g., cents)
    # @param currency_code [String] ISO 4217 currency code, e.g. `"USD"`
    # @return [Coin]
    # @raise [TypeError] if `currency_minor` is not an Integer
    #
    # @example
    #   Coin.value(2999, 'USD')  # => $29.99
    #   Coin.value(0, 'JPY')     # => ¥0
    def value(currency_minor, currency_code)
      raise TypeError unless currency_minor.is_a?(Integer)

      new(currency_minor:, currency_code:)
    end

    # Returns a zero-valued Coin in the given currency.
    #
    # @param currency_code [String] ISO 4217 currency code
    # @return [Coin]
    #
    # @example
    #   Coin.zero('USD')  # => $0.00
    def zero(currency_code)
      new(currency_minor: 0, currency_code:)
    end

    # Parses a heterogeneous input into a Coin using {Coin::Parser}.
    #
    # Accepted input types: {Coin}, {Money}, {Numeric}, {String}.
    #
    # @param value [Coin, Money, Numeric, String] the value to parse
    # @param currency_code [String, nil] required for Numeric and bare String inputs
    # @return [Coin]
    # @raise [TypeError] if the input type cannot be converted
    # @raise [ArgumentError] if a currency_code is required but not provided
    #
    # @example
    #   Coin.parse(Money.new(2999, 'USD'))
    #   Coin.parse(29.99, currency_code: 'USD')
    #   Coin.parse('$29.99')
    def parse(value, currency_code: nil)
      Parser.parse(value, currency_code:)
    end
  end

  # ── Deprecated ────────────────────────────────────────────────────────── #

  # @deprecated Use {#resource_role} instead. Will be removed in v0.4.0.
  def resource_label
    WhittakerTech::Midas::Deprecation.warn(
      'Coin#resource_label is deprecated. Use Coin#resource_role instead.',
      caller_locations(1, 1)&.first
    )
    resource_role
  end

  # @deprecated Use {#resource_role=} instead. Will be removed in v0.4.0.
  def resource_label=(value)
    WhittakerTech::Midas::Deprecation.warn(
      'Coin#resource_label= is deprecated. Use Coin#resource_role= instead.',
      caller_locations(1, 1)&.first
    )
    self.resource_role = value
  end

  # @deprecated Use {.for_role} instead. Will be removed in v0.4.0.
  def self.for_label(label)
    WhittakerTech::Midas::Deprecation.warn(
      'Coin.for_label is deprecated. Use Coin.for_role instead.',
      caller_locations(1, 1)&.first
    )
    for_role(label)
  end

  private

  # Normalizes currency_code before validation.
  #
  # - `currency_code` is stripped and capitalized
  # - `resource_role` normalisation is handled by {Poly::Role}
  # @return [void]
  def normalize_currency_code
    self.currency_code = currency_code.to_s.strip.upcase.presence if currency_code
  end
end
# rubocop:enable Metrics/ClassLength
