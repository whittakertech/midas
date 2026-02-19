# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Coin do
  describe 'associations' do
    it { should belong_to(:resource).optional(false) }
  end

  describe 'validations' do
    subject(:coin) { create(:wt_midas_coin) }

    it { should validate_presence_of(:resource_role) }

    %w[price cost value money subtotal tax total shipping].each do |label|
      it { should allow_value(label).for(:resource_role) }
    end

    it do
      expect(coin).to validate_uniqueness_of(:resource_role)
        .scoped_to(%i[resource_type resource_id])
        .case_insensitive
    end

    it { should validate_presence_of(:currency_code) }
    it { should validate_length_of(:currency_code).is_equal_to(3) }

    it { should validate_presence_of(:currency_minor) }
    it { should validate_numericality_of(:currency_minor).only_integer }
  end

  describe 'table_name' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('wt_midas_coins')
    end
  end

  describe '#amount' do
    let(:cents) { 1299 }
    let(:currency_code) { 'USD' }
    let(:coin) { create(:wt_midas_coin, currency_minor: cents, currency_code: currency_code) }
    let(:amount) { coin.amount }

    it 'returns a Money object' do
      expect(amount).to be_a(Money)
    end

    it 'returns a Money object with correct cents' do
      expect(amount.cents).to eq(cents)
    end

    it 'returns a Money object with correct currency' do
      expect(amount.currency.iso_code).to eq(currency_code)
    end
  end

  describe '#amount=' do
    let(:coin) { build(:wt_midas_coin) }

    context 'when setting with a Money object' do
      it 'sets currency_minor and currency_code from Money object' do
        money = Money.new(2599, 'EUR')
        coin.amount = money

        expect(coin.currency_minor).to eq(2599)
        expect(coin.currency_code).to eq('EUR')
      end
    end

    context 'when setting with a numeric value' do
      it 'sets currency_minor to the numeric value' do
        coin.amount = 1500
        expect(coin.currency_minor).to eq(1500)
      end
    end

    context 'when setting with an invalid value' do
      it 'raises ArgumentError for string values' do
        expect { coin.amount = 'invalid' }
          .to raise_error(ArgumentError, /Invalid value for Coin#amount: "invalid"/)
      end

      it 'raises ArgumentError for nil values' do
        expect { coin.amount = nil }
          .to raise_error(ArgumentError, /Invalid value for Coin#amount: nil/)
      end

      it 'raises ArgumentError for array values' do
        expect { coin.amount = [100] }
          .to raise_error(ArgumentError, /Invalid value for Coin#amount: \[100\]/)
      end
    end

    it 'raises error when setting numeric without currency' do
      coin = build(:wt_midas_coin, currency_code: nil)
      expect { coin.amount = 100 }
        .to raise_error(ArgumentError, /currency_code required/)
    end
  end

  describe '#format' do
    let(:coin) { create(:wt_midas_coin, currency_minor: 1299, currency_code: 'USD') }

    context 'without currency conversion' do
      it 'formats the amount in its original currency' do
        formatted = coin.format

        expect(formatted).to be_a(String)
        expect(formatted).to include('12.99')
      end
    end
  end

  describe 'convenience methods' do
    let(:coin) { create(:wt_midas_coin, currency_minor: 1234, currency_code: 'USD') }

    it 'provides minor alias for currency_minor' do
      expect(coin.minor).to eq(1234)
    end

    it 'provides currency alias for currency_code' do
      expect(coin.currency).to eq('USD')
    end

    it 'provides fractional alias for currency_minor' do
      expect(coin.fractional).to eq(1234)
    end
  end

  describe 'normalization' do
    it 'normalizes currency_code to uppercase' do
      coin = build(:wt_midas_coin, currency_code: 'usd')
      coin.valid?
      expect(coin.currency_code).to eq('USD')
    end

    it 'normalizes resource_role to lowercase' do
      coin = build(:wt_midas_coin, resource_role: 'Price')
      coin.valid?
      expect(coin.resource_role).to eq('price')
    end

    it 'strips whitespace from currency_code' do
      coin = build(:wt_midas_coin, currency_code: ' EUR ')
      coin.valid?
      expect(coin.currency_code).to eq('EUR')
    end
  end

  describe 'memoization' do
    let(:coin) { create(:wt_midas_coin) }

    it 'memoizes amount' do
      first = coin.amount
      second = coin.amount
      expect(first.object_id).to eq(second.object_id)
    end

    it 'clears memoization when currency_minor changes' do
      first = coin.amount
      coin.currency_minor = 5000
      second = coin.amount
      expect(first.object_id).not_to eq(second.object_id)
    end
  end

  describe 'integration tests' do
    let(:coin) { create(:wt_midas_coin) }

    it 'can be created with valid attributes' do
      expect(coin).to be_valid
      expect(coin).to be_persisted
    end

    it 'maintains data integrity through amount setter and getter' do
      original_money = Money.new(5000, 'GBP')
      coin.amount = original_money
      coin.save!

      coin.reload
      retrieved_amount = coin.amount

      expect(retrieved_amount.cents).to eq(original_money.cents)
      expect(retrieved_amount.currency.iso_code).to eq(original_money.currency.iso_code)
    end
  end

  describe '#allocate' do
    let(:coin) { described_class.value(1000, 'USD') }

    it 'returns a Coin::Allocation' do
      allocation = coin.allocate(per: 4)

      expect(allocation).to be_a(WhittakerTech::Midas::Coin::Allocation)
      expect(allocation.coin).to eq(coin)
      expect(allocation.divisor).to eq(4)
    end

    it 'passes through the rounding policy' do
      allocation = coin.allocate(per: 3, rounding_policy: :ceil)

      expect(allocation.rounding_policy).to eq(:ceil)
    end
  end

  describe '#decimals' do
    it 'returns the correct decimal places for USD' do
      coin = described_class.value(1000, 'USD')
      expect(coin.decimals).to eq(2)
    end

    it 'returns correct decimal places for JPY (zero-decimal currency)' do
      coin = described_class.value(1000, 'JPY')
      expect(coin.decimals).to eq(0)
    end
  end

  describe '#scale' do
    it 'returns 10^decimals' do
      coin = described_class.value(1000, 'USD')

      expect(coin.scale).to eq(100)
      expect(coin.scale).to eq(10**coin.decimals)
    end
  end

  describe '#major' do
    it 'returns major units as BigDecimal' do
      coin = described_class.value(1234, 'USD')

      expect(coin.major).to be_a(BigDecimal)
      expect(coin.major).to eq(BigDecimal('12.34'))
    end

    it 'does not apply rounding' do
      coin = described_class.value(1, 'USD')

      expect(coin.major).to eq(BigDecimal('0.01'))
    end
  end

  describe '.zero' do
    it 'returns a zero-valued Coin for the given currency' do
      coin = described_class.zero('USD')

      expect(coin.currency_minor).to eq(0)
      expect(coin.currency_code).to eq('USD')
    end
  end

  describe '.parse' do
    let(:coin) { described_class.value(1000, 'USD') }

    it 'returns the coin unchanged when given a Coin' do
      expect(described_class.parse(coin)).to eq(coin)
    end

    it 'parses a Money object' do
      money = Money.new(1500, 'USD')

      parsed = described_class.parse(money)

      expect(parsed).to eq(described_class.value(1500, 'USD'))
    end

    it 'parses a Numeric with explicit currency_code' do
      parsed = described_class.parse(12.34, currency_code: 'USD')

      expect(parsed.currency_minor).to eq(1234)
      expect(parsed.currency_code).to eq('USD')
    end

    it 'rejects Numeric without currency_code' do
      expect { described_class.parse(12.34) }.to raise_error(ArgumentError, /currency_code required/)
    end

    it 'rejects unsupported types' do
      expect { described_class.parse(Object.new) }.to raise_error(TypeError)
    end
  end

  describe '.parse (string handling)' do
    it 'parses a numeric string with explicit currency' do
      parsed = described_class.parse('12.34', currency_code: 'USD')

      expect(parsed).to eq(described_class.value(1234, 'USD'))
    end

    it 'parses a currency-prefixed string' do
      parsed = described_class.parse('$12.34')

      expect(parsed.currency_minor).to eq(1234)
      expect(parsed.currency_code).to eq(Money.default_currency.iso_code)
    end

    it 'raises when string lacks currency context' do
      expect { described_class.parse('12.34') }.to raise_error(ArgumentError, /Currency code required/)
    end
  end

  describe 'edge cases' do
    context 'with zero amount' do
      let(:coin) { create(:wt_midas_coin, currency_minor: 0) }

      it 'handles zero amounts correctly' do
        expect(coin.amount.cents).to eq(0)
        expect(coin.format).to include('0.00')
      end
    end

    context 'with negative amounts' do
      let(:coin) { create(:wt_midas_coin, currency_minor: -500) }

      it 'handles negative amounts correctly' do
        expect(coin.amount.cents).to eq(-500)
        expect(coin.format).to include('-5.00')
      end
    end

    context 'with large amounts' do
      let(:coin) { create(:wt_midas_coin, currency_minor: 999_999_999) }

      it 'handles large amounts correctly' do
        expect(coin.amount.cents).to eq(999_999_999)
        expect(coin.format).to include('$9,999,999.99')
      end
    end
  end
end
