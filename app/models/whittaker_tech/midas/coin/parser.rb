# frozen_string_literal: true

class WhittakerTech::Midas::Coin::Parser
  class << self
    def parse(value, currency_code: nil)
      case value
      when WhittakerTech::Midas::Coin
        value
      when Money
        WhittakerTech::Midas::Coin.value(value.cents, value.currency.iso_code)
      when Numeric
        parse_numeric(value, currency_code)
      when String
        parse_string(value, currency_code)
      else
        raise TypeError, "Cannot convert #{value.class} to Coin"
      end
    end

    private

    def parse_numeric(value, currency_code)
      raise ArgumentError, 'currency_code required' unless currency_code

      money = Money.from_amount(value, currency_code)
      WhittakerTech::Midas::Coin.value(money.cents, money.currency.iso_code)
    end

    def parse_string(str, currency_code)
      stripped = str.strip

      money =
        if currency_code
          Money.from_amount(extract_number(stripped), currency_code)
        elsif stripped =~ /[^\d.\s]/
          Money.from_amount(extract_number(stripped), Money.default_currency)
        else
          raise ArgumentError, 'Currency code required for string amounts'
        end

      WhittakerTech::Midas::Coin.value(money.cents, money.currency.iso_code)
    end

    def extract_number(str)
      BigDecimal(str.gsub(/[^\d.]/, ''))
    end
  end
end
