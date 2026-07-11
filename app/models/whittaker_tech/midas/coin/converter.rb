# frozen_string_literal: true

# Converter implements cross-currency conversion for Coin, backed by a
# provider-agnostic adapter (default: Coin::Converter::BankProvider wrapping
# Money.default_bank). Every successful conversion writes an immutable
# WhittakerTech::Midas::Exchange audit row, which owns both a copy of the
# source value (`from`) and the converted result (`to`).
#
# @since 0.3.0
module WhittakerTech::Midas::Coin::Converter
  # Converts this Coin to another currency.
  #
  # The receiver does not need to be persisted — it's only ever read, never
  # mutated or reassigned. The result is a brand-new, persisted Coin owned
  # by a newly created Exchange audit row (not linked back to this Coin's
  # own resource).
  #
  # @param currency_code [String] target ISO 4217 currency code
  # @param at [Time, nil] rate timestamp; nil (default) means "now". A
  #   non-nil value requires `using:` to supply a provider implementing
  #   `#exchange_at`.
  # @param using [Object, Money::Bank::Base, nil] provider override; any
  #   object responding to `#exchange(money, currency_code)` and `#name`,
  #   or a raw `Money::Bank::*` instance (auto-wrapped in BankProvider)
  # @return [Coin] the persisted `to` Coin (the converted result), owned by
  #   the newly created Exchange audit row
  # @raise [ArgumentError] if `at` is given and the resolved provider has
  #   no `#exchange_at`
  def convert_to(currency_code, at: nil, using: nil)
    provider = resolve_provider(using)
    iso = currency_code.to_s.strip.upcase

    if currency_minor.zero?
      converted_cents = 0
      rate = BigDecimal(0)
    else
      converted = fetch_rate(provider, iso, at)
      converted_cents = converted.cents
      rate = BigDecimal(converted_cents) / BigDecimal(currency_minor)
    end

    persist_conversion(provider, iso, at, converted_cents, rate)
  end
  alias exchange_to convert_to

  private

  def resolve_provider(using)
    case using
    when nil then WhittakerTech::Midas::Coin::Converter::BankProvider.new
    when Money::Bank::Base then WhittakerTech::Midas::Coin::Converter::BankProvider.new(using)
    else using
    end
  end

  def fetch_rate(provider, iso, at)
    return provider.exchange(amount, iso) if at.nil?

    unless provider.respond_to?(:exchange_at)
      raise ArgumentError,
            "#{provider.respond_to?(:name) ? provider.name : provider.class.name} does not support " \
            'historical rates (at:); omit at: or supply a provider implementing #exchange_at'
    end

    provider.exchange_at(amount, iso, at:)
  end

  def persist_conversion(provider, iso, at, minor, rate)
    source = provider.respond_to?(:name) ? provider.name : provider.class.name
    stamp = at || Time.current

    WhittakerTech::Midas::Coin.transaction do
      exchange = WhittakerTech::Midas::Exchange.create!(rate:, source:, at: stamp)
      exchange.set_from(amount: currency_minor, currency_code: currency_code)
      exchange.set_to(amount: minor, currency_code: iso)
      exchange.to
    end
  end
end
