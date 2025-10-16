# frozen_string_literal: true

module WhittakerTech
  module Midas
    # The Coin model represents a monetary value with an associated currency.
    # It serves as the storage mechanism for monetary amounts used by the Bankable module,
    # providing a polymorphic association to any model that includes Bankable functionality.
    #
    # Coins store monetary values using the minor currency unit (cents, pence, etc.) to
    # avoid floating-point precision issues. The model integrates with the Money gem
    # to provide rich currency handling, formatting, and exchange capabilities.
    #
    # @example Creating a coin
    #   coin = WhittakerTech::Midas::Coin.create!(
    #     resource: product,
    #     resource_label: 'price',
    #     currency_code: 'USD',
    #     currency_minor: 2999  # $29.99
    #   )
    #
    # @example Working with amounts
    #   coin.amount                    # => #<Money:0x... @cents=2999 @currency="USD">
    #   coin.amount.format            # => "$29.99"
    #   coin.exchange_to('EUR')       # => #<Money:0x... @cents=2685 @currency="EUR">
    #   coin.format(to: 'EUR')        # => "€26.85"
    #
    # @example Setting amounts
    #   coin.amount = Money.new(3499, 'USD')
    #   coin.amount = 3499  # Sets currency_minor directly
    #
    # == Database Schema
    #
    # The model uses the table `wt_midas_coins` with the following key columns:
    # - `resource_id`: Foreign key to the associated model
    # - `resource_type`: Class name of the associated model (polymorphic)
    # - `resource_label`: String identifier for the specific monetary attribute
    # - `currency_code`: ISO 4217 three-letter currency code (e.g., 'USD', 'EUR')
    # - `currency_minor`: Integer value in the currency's minor unit
    #
    # == Associations
    #
    # - `resource`: Polymorphic belongs_to association to the model that owns this coin
    #
    # == Validations
    #
    # - `resource_label`: Must be present
    # - `currency_code`: Must be present and exactly 3 characters long
    # - `currency_minor`: Must be present and an integer
    #
    # == Currency Handling
    #
    # The model leverages the Money gem for currency operations:
    # - Automatic conversion between minor units and Money objects
    # - Currency exchange using configured exchange rates
    # - Proper formatting according to currency conventions
    # - Precision handling to avoid floating-point errors
    #
    # == Usage with Bankable
    #
    # Coins are typically not created directly but through the Bankable module:
    #
    # @example
    #   class Product < ApplicationRecord
    #     include WhittakerTech::Midas::Bankable
    #     has_coin :price
    #   end
    #
    #   product = Product.create!
    #   product.set_price(amount: 29.99, currency_code: 'USD')
    #   # This creates a Coin with resource_label: 'price'
    #
    # == Thread Safety
    #
    # This model follows standard Active Record patterns and is thread-safe
    # when used within Rails' standard threading model.
    #
    # @see WhittakerTech::Midas::Bankable
    # @see Money
    # @since 0.1.0
    class Coin < ApplicationRecord
      self.table_name = 'wt_midas_coins'

      belongs_to :resource, polymorphic: true

      validates :resource_label, presence: true,
                                 format: { with: /\A[a-z0-9_]+\z/ },
                                 uniqueness: { scope: %i[resource_type resource_id] }
      validates :currency_code,  presence: true, length: { is: 3 }
      validates :currency_minor, presence: true, numericality: { only_integer: true }

      # Returns a Money object representing the stored monetary value.
      #
      # The Money object is constructed from the stored currency_minor value
      # and currency_code, providing access to all Money gem functionality
      # including formatting, arithmetic operations, and currency conversion.
      #
      # @return [Money] A Money object representing the coin's value
      #
      # @example
      #   coin = Coin.new(currency_minor: 2999, currency_code: 'USD')
      #   coin.amount # => #<Money:0x... @cents=2999 @currency="USD">
      #   coin.amount.format # => "$29.99"
      def amount
        Money.new(currency_minor, currency_code)
      end

      # Sets the coin's monetary value from various input types.
      #
      # Accepts either a Money object or a numeric value. When a Money object
      # is provided, both the amount and currency are updated. When a numeric
      # value is provided, only the currency_minor field is updated.
      #
      # @param value [Money, Numeric] The value to set
      # @raise [ArgumentError] If the value type is not supported
      #
      # @example With Money object
      #   coin.amount = Money.new(2999, 'USD')
      #   coin.currency_minor # => 2999
      #   coin.currency_code  # => 'USD'
      #
      # @example With numeric value
      #   coin.amount = 3499
      #   coin.currency_minor # => 3499
      def amount=(value)
        case value
        when Money
          self.currency_minor = value.cents
          self.currency_code = value.currency.iso_code
        when Numeric
          self.currency_minor = value
        else
          raise ArgumentError, "Invalid value for Coin#amount: #{value.inspect}"
        end
      end

      # Exchanges the coin's amount to a different currency.
      #
      # Uses the Money gem's exchange functionality to convert the current
      # amount to the specified target currency. Requires exchange rates
      # to be configured in the Money gem.
      #
      # @param new_currency [String, Symbol] The target currency code
      # @return [Money] A new Money object in the target currency
      #
      # @example
      #   usd_coin = Coin.new(currency_minor: 2999, currency_code: 'USD')
      #   eur_amount = usd_coin.exchange_to('EUR')
      #   eur_amount.currency.iso_code # => 'EUR'
      #
      # @see Money#exchange_to
      delegate :exchange_to, to: :amount

      # Returns a formatted string representation of the coin's value.
      #
      # Optionally converts to a different currency before formatting.
      # The formatting follows the conventions of the target currency,
      # including proper symbol placement and decimal formatting.
      #
      # @param to [String, Symbol, nil] Optional target currency for conversion
      # @return [String] Formatted monetary amount
      #
      # @example Basic formatting
      #   coin = Coin.new(currency_minor: 2999, currency_code: 'USD')
      #   coin.format # => "$29.99"
      #
      # @example Formatting with currency conversion
      #   coin.format(to: 'EUR') # => "€26.85"
      #
      # @see Money#format
      def format(to: nil)
        (to ? exchange_to(to) : amount).format
      end
    end
  end
end
