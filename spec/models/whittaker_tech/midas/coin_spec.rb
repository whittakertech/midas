# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Coin do
  describe 'associations' do
    it { should belong_to(:resource).optional(false) }
  end

  describe 'validations' do
    subject { create(:wt_midas_coin) }

    it { should validate_presence_of(:resource_label) }
    it { should validate_presence_of(:currency_code) }
    it { should validate_presence_of(:currency_minor) }
    it { should validate_length_of(:currency_code).is_equal_to(3) }
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
  end

  describe '#exchange_to' do
    let(:coin) { create(:wt_midas_coin, currency_minor: 1000, currency_code: 'USD') }

    before do
      Money.default_bank.add_rate('USD', 'EUR', 0.85)
    end

    after do
      Money.default_bank.rates.clear
    end

    it 'returns exchanged Money object in new currency' do
      exchanged = coin.exchange_to('EUR')

      expect(exchanged).to be_a(Money)
      expect(exchanged.currency.iso_code).to eq('EUR')
      expect(exchanged.cents).to eq(850)
    end

    it 'delegates to Money#exchange_to method' do
      money_double = instance_double(Money)
      allow(coin).to receive(:amount).and_return(money_double)
      allow(money_double).to receive(:exchange_to).with('GBP')

      coin.exchange_to('GBP')

      expect(money_double).to have_received(:exchange_to).with('GBP')
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

    context 'with currency conversion' do
      before do
        Money.default_bank.add_rate('USD', 'EUR', 0.85)
      end

      after do
        Money.default_bank.rates.clear
      end

      it 'exchanges to new currency before formatting' do
        formatted = coin.format(to: 'EUR')

        expect(formatted).to be_a(String)
        expect(formatted).to include('11.04')
      end

      it 'uses mocked exchange for testing' do
        money_double = instance_double(Money)
        exchanged_money = instance_double(Money)

        allow(coin).to receive(:amount).and_return(money_double)
        allow(money_double).to receive(:exchange_to).with('EUR').and_return(exchanged_money)
        allow(exchanged_money).to receive(:format).and_return('€11.50')

        result = coin.format(to: 'EUR')

        expect(result).to eq('€11.50')
      end
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

      expect(retrieved_amount.cents).to eq(5000)
      expect(retrieved_amount.currency.iso_code).to eq('GBP')
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
