# frozen_string_literal: true

module WhittakerTech
  module Midas
    # The Bankable module provides currency and monetary value management functionality
    # for Active Record models. It allows models to have associated monetary values
    # (coins) with different currencies and provides convenient methods for setting,
    # retrieving, and formatting these values.
    #
    # When included in a model, Bankable automatically sets up a polymorphic association
    # to the Midas::Coin model and provides class methods to define specific monetary
    # attributes.
    #
    # @example Basic usage
    #   class Product < ApplicationRecord
    #     include WhittakerTech::Midas::Bankable
    #
    #     has_coin :price
    #   end
    #
    #   # Create and set a price
    #   product = Product.create!
    #   product.set_price(amount: 29.99, currency_code: 'USD')
    #
    #   # Access the price
    #   product.price          # => Coin object
    #   product.price_amount   # => Money object
    #   product.price_format   # => "$29.99"
    #   product.price_in(:eur) # => "€26.85" (if exchange rates available)
    #
    # @example Multiple coins
    #   class Invoice < ApplicationRecord
    #     include WhittakerTech::Midas::Bankable
    #
    #     has_coins :subtotal, :tax, :total
    #   end
    #
    # @example Custom dependency handling
    #   class Order < ApplicationRecord
    #     include WhittakerTech::Midas::Bankable
    #
    #     has_coin :deposit, dependent: :nullify
    #   end
    #
    # == Associations Created
    #
    # When included, the module automatically creates:
    # - `midas_coins`: A polymorphic has_many association to all Coin records
    #   associated with this model instance
    #
    # == Methods Created by has_coin
    #
    # For each coin defined with `has_coin :name`, the following methods are created:
    #
    # - `name`: Returns the associated Coin object
    # - `name_amount`: Returns the Money object representing the amount
    # - `name_format`: Returns a formatted string representation of the amount
    # - `name_in(currency)`: Returns the amount converted to the specified currency
    # - `set_name(amount:, currency_code:)`: Sets the coin value with the given amount and currency
    #
    # == Supported Amount Types
    #
    # The `set_*` methods accept amounts in various formats:
    # - Money objects: Used directly for cents value
    # - Integer: Treated as cents/minor currency units
    # - Numeric: Converted to cents using currency-specific decimal places
    #
    # == Currency Configuration
    #
    # The module uses I18n for currency-specific configuration:
    # - `midas.ui.currencies.{ISO_CODE}.decimal_count`: Decimal places for specific currency
    # - `midas.ui.defaults.decimal_count`: Default decimal places (defaults to 2)
    #
    # == Thread Safety
    #
    # This module is designed to be thread-safe when used with Rails' standard
    # Active Record patterns.
    #
    # @see WhittakerTech::Midas::Coin
    # @since 0.1.0
    module Bankable
      extend ActiveSupport::Concern

      included do
        has_many :midas_coins,
                 as: :resource,
                 class_name: 'WhittakerTech::Midas::Coin',
                 dependent: :destroy
      end

      class_methods do
        # Defines multiple coin attributes at once.
        #
        # @param names [Array<Symbol>] The names of the coin attributes to define
        # @param dependent [Symbol] The dependency behavior when the parent record is destroyed
        #   (:destroy, :delete_all, :nullify, :restrict_with_exception, :restrict_with_error)
        #
        # @example
        #   has_coins :price, :cost, :tax
        #   has_coins :deposit, :refund, dependent: :nullify
        def has_coins(*names, dependent: :destroy)
          names.each { |name| has_coin(name, dependent:) }
        end

        # Defines a single coin attribute with associated methods and database relationship.
        #
        # This method creates:
        # - A has_one association to the Coin model
        # - Getter and setter methods for the coin
        # - Helper methods for amount access and formatting
        #
        # @param name [Symbol] The name of the coin attribute
        # @param dependent [Symbol] The dependency behavior when the parent record is destroyed
        #
        # @example
        #   has_coin :price
        #   has_coin :refundable_deposit, dependent: :nullify
        def has_coin(name, dependent: :destroy)
          label = name.to_s
          assoc_name = :"#{name}_coin"

          has_one assoc_name,
                  -> { where(resource_label: label) },
                  as: :resource,
                  class_name: 'WhittakerTech::Midas::Coin',
                  dependent: dependent

          define_methods(name, label, assoc_name)
        end

        def define_methods(name, label, assoc_name)
          define_method(name) { public_send(assoc_name) }

          define_method("#{name}_amount")   { public_send(name)&.amount }
          define_method("#{name}_format")   { public_send(name)&.amount&.format }
          define_method("#{name}_in")       { |to| public_send(name)&.exchange_to(to)&.format }

          # Sets the coin value with the specified amount and currency.
          #
          # @param amount [Money, Integer, Numeric] The amount to set
          # @param currency_code [String, Symbol] The ISO currency code (e.g., 'USD', 'EUR')
          # @return [Coin] The created or updated Coin object
          # @raise [ArgumentError] If the amount type is not supported
          #
          # @example
          #   product.set_price(amount: 29.99, currency_code: 'USD')
          #   product.set_price(amount: Money.new(2999, 'USD'), currency_code: 'USD')
          #   product.set_price(amount: 2999, currency_code: 'USD') # 2999 cents
          define_method("set_#{name}") do |amount:, currency_code:|
            iso = currency_code.to_s.upcase
            coin = public_send(name) || public_send("build_#{assoc_name}", resource_label: label)
            coin.currency_code  = iso
            coin.currency_minor = to_cents(amount, iso)
            coin.resource       = self
            coin.save!

            coin
          end
        end
      end

      private

      def to_cents(amount, iso)
        raise ArgumentError, "Invalid value for #{name}: #{amount.inspect}" unless is_valid_type?(amount)

        return amount.cents if amount.is_a? Money
        return amount if amount.is_a? Integer

        (BigDecimal(amount.to_s) * (10**decimals_for(iso))).round.to_i
      end

      def is_valid_type?(amount)
        [Money, Integer, Numeric].any? { |klass| amount.is_a?(klass) }
      end

      # Determines the number of decimal places for a given currency.
      #
      # @param iso [String] The ISO currency code
      # @return [Integer] Number of decimal places (0-12)
      def decimals_for(iso)
        scope    = 'midas.ui'
        per      = I18n.t("#{scope}.currencies.#{iso}", default: {})
        default  = I18n.t("#{scope}.defaults.decimal_count", default: 2)
        (per['decimal_count'] || default).to_i.clamp(0, 12)
      end
    end
  end
end
