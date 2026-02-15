# frozen_string_literal: true

# Coin is the canonical, persisted representation of a monetary value.
#
# Conceptually:
# - Coin represents *payable money* (integer minor units, specific currency)
# - Coin is immutable by convention (operations return new Coins)
# - Coin owns arithmetic truth, not presentation or pricing interpretation
#
# Coin participates in persistence (ActiveRecord) but exposes
# value-object semantics via mixins (Arithmetic, Converter).
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

  # Normalize user input before validation to ensure consistent storage
  before_validation :normalize_fields

  # Each resource may only have one Coin per resource_label
  validates :resource_label,
            presence: true,
            format: { with: /\A[a-z0-9_]+\z/ },
            length: { maximum: 64 },
            uniqueness: { scope: %i[resource_type resource_id], case_sensitive: false }

  # Currency code is stored as a 3-letter ISO string (e.g. "USD")
  validates :currency_code,  presence: true, length: { is: 3 }

  # Minor units are always stored as integers
  validates :currency_minor, presence: true, numericality: { only_integer: true }

  # Returns a Money object representing the stored monetary value.
  #
  # This is a *projection*, not the canonical value.
  # Memoized for performance, cleared when underlying fields change.
  def amount
    @amount ||= Money.new(currency_minor, currency_code)
  end

  # Sets the coin's monetary value from supported input types.
  #
  # NOTE:
  # - Numeric assignment assumes the value is already in minor units.
  # - No rounding or scaling is performed here
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

  # Formats the Coin for display, optionally converting currency
  #
  # This is a convenience wrapper; full formatting customization
  # belongs in a dedicated formatter layer.
  def format(to: nil)
    (to ? exchange_to(to) : amount).format
  end

  # Scalar accessors for form helpers and introspection
  def minor
    currency_minor
  end

  def currency
    currency_code
  end

  def fractional
    currency_minor
  end

  # Clear memoized Money projection when underlying data changes
  def currency_minor=(value)
    @amount = nil
    super
  end

  def currency_code=(value)
    @amount = nil
    super
  end

  # Constructs an Allocation object representing this Coin
  # interpreted per N units using a named rounding policy.
  #
  # Coin remains unchanged; Allocation encapsulates interpretation.
  # @return [WhittakerTech::Midas::Coin::Allocation]
  def allocate(per:, rounding_policy: WhittakerTech::Midas::DEFAULT_ROUNDING_POLICY)
    WhittakerTech::Midas::Coin::Allocation.new(
      coin: self,
      divisor: per,
      rounding_policy:
    )
  end

  # Returns the number of decimal places for the currency.
  #
  # This is informational and does not imply rounding or formatting.
  def decimals
    Money::Currency.new(currency_code).decimal_places
  end

  # Returns the scaling factor for converting major to minor units.
  def scale
    10**decimals
  end

  # Returns the major-unit value as a BigDecimal.
  #
  # NOTE:
  # - This is *not* payable money
  # - No rounding policy is applied
  # - Intended for inspection and formatting only
  def major
    BigDecimal(currency_minor) / scale
  end

  class << self
    # Constructs a Coin directly from minor units and currency code.
    #
    # This is the lowest-level factory and enforces integer minor units.
    def value(currency_minor, currency_code)
      raise TypeError unless currency_minor.is_a?(Integer)

      new(currency_minor:, currency_code:)
    end

    # Convenience constructor for a zero-valued Coin.
    def zero(currency_code)
      new(currency_minor: 0, currency_code:)
    end

    def parse(value, currency_code: nil)
      Parser.parse(value, currency_code:)
    end
  end

  private

  # Normalizes user input to ensure consistency and reliable uniqueness.
  def normalize_fields
    self.resource_label = resource_label.to_s.strip.downcase.presence if resource_label
    self.currency_code = currency_code.to_s.strip.upcase.presence if currency_code
  end
end
