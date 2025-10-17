# frozen_string_literal: true

module WhittakerTech
  module Midas
    class Coin < ApplicationRecord
      self.table_name = 'wt_midas_coins'

      belongs_to :resource, polymorphic: true

      before_validation :normalize_fields

      validates :resource_label,
                presence: true,
                format: { with: /\A[a-z0-9_]+\z/ },
                length: { maximum: 64 },
                uniqueness: { scope: %i[resource_type resource_id], case_sensitive: false }

      validates :currency_code,  presence: true, length: { is: 3 }
      validates :currency_minor, presence: true, numericality: { only_integer: true }

      # Returns a Money object representing the stored monetary value.
      # Memoized for performance in hot paths.
      def amount
        @amount ||= Money.new(currency_minor, currency_code)
      end

      # Sets the coin's monetary value from various input types.
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

      delegate :exchange_to, to: :amount

      def format(to: nil)
        (to ? exchange_to(to) : amount).format
      end

      # Convenient aliases for form helpers
      def minor
        currency_minor
      end

      def currency
        currency_code
      end

      def fractional
        currency_minor
      end

      # Override setters to clear memoization
      def currency_minor=(value)
        @amount = nil
        super
      end

      def currency_code=(value)
        @amount = nil
        super
      end

      private

      # Normalize inputs for consistency and case-insensitive uniqueness
      def normalize_fields
        self.resource_label = resource_label.to_s.strip.downcase.presence if resource_label
        self.currency_code = currency_code.to_s.strip.upcase.presence if currency_code
      end
    end
  end
end
