# frozen_string_literal: true

# Default currency-conversion provider: wraps Money.default_bank (or any
# explicit Money::Bank::* instance) behind the adapter interface
# WhittakerTech::Midas::Coin::Converter expects.
#
# Adapter interface (duck-typed):
#   #exchange(money, currency_code) -> Money
#   #name -> String                             (recorded as Exchange#source)
#   #exchange_at(money, currency_code, at:) -> Money   (optional; only
#     needed to support a non-default at:. This provider does not define
#     it — the default Money::Bank::VariableExchange has no historical
#     capability at all.)
#
# @since 0.3.0
class WhittakerTech::Midas::Coin::Converter::BankProvider
  def initialize(bank = Money.default_bank)
    @bank = bank
  end

  # @param money [Money] the value to convert (native currency)
  # @param currency_code [String] target ISO 4217 code
  # @return [Money]
  def exchange(money, currency_code)
    # NOTE: deliberately NOT `money.exchange_to(currency_code)` — that
    # method hardcodes Money.default_bank internally (money gem 6.x) and
    # would silently ignore a `using:` override. Call the bank directly.
    @bank.exchange_with(money, Money::Currency.new(currency_code))
  end

  # @return [String] recorded on Exchange#source
  def name
    "money:#{@bank.class.name}"
  end
end
