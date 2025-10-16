# frozen_string_literal: true

Money.locale_backend = nil
Money.rounding_mode = BigDecimal::ROUND_HALF_EVEN
Money.default_bank = Money::Bank::VariableExchange.new

Money.default_formatting_rules = {
  display_free: false,
  with_currency: false,
  no_cents_if_whole: false,
  format: '%u%n',
  thousands_separator: ',',
  decimal_mark: '.'
}
