# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Coin::Converter do
  around do |example|
    original_bank = Money.default_bank
    Money.default_bank = Money::Bank::VariableExchange.new
    Money.default_bank.add_rate('USD', 'EUR', 0.85)
    Money.default_bank.add_rate('EUR', 'USD', 1.18)
    example.run
    Money.default_bank = original_bank
  end

  describe '#convert_to' do
    context 'with a persisted coin' do
      let(:coin) { create(:midas_coin, currency_minor: 2999, currency_code: 'USD') }

      it 'returns a persisted Coin in the target currency' do
        result = coin.convert_to('EUR')

        expect(result).to be_a(WhittakerTech::Midas::Coin)
        expect(result).to be_persisted
      end

      it 'converts the amount using the currency rate' do
        result = coin.convert_to('EUR')

        expect(result.currency_code).to eq('EUR')
        expect(result.currency_minor).to eq(2549)
      end

      it 'records an Exchange audit row with a from coin distinct from the original' do
        coin.convert_to('EUR')
        exchange = WhittakerTech::Midas::Exchange.last

        expect(exchange.from.currency_code).to eq('USD')
        expect(exchange.from.currency_minor).to eq(2999)
        expect(exchange.from.id).not_to eq(coin.id)
      end

      it 'records an Exchange audit row linking to the converted result' do
        result = coin.convert_to('EUR')
        exchange = WhittakerTech::Midas::Exchange.last

        expect(exchange.to).to eq(result)
        expect(exchange.source).to eq('money:Money::Bank::VariableExchange')
      end

      it 'records rate and timestamp on the Exchange audit row' do
        coin.convert_to('EUR')
        exchange = WhittakerTech::Midas::Exchange.last

        expect(exchange.rate).to be_present
        expect(exchange.at).to be_present
      end
    end

    context 'with an unsaved coin' do
      let(:coin) { WhittakerTech::Midas::Coin.value(2999, 'USD') }

      it 'does not require the receiver to be persisted' do
        result = coin.convert_to('EUR')

        expect(result).to be_persisted
        expect(result.currency_code).to eq('EUR')
      end
    end

    it 'is aliased as #exchange_to' do
      coin = create(:midas_coin, currency_minor: 2999, currency_code: 'USD')

      expect(coin.method(:exchange_to)).to eq(coin.method(:convert_to))
    end

    context 'with a historical at: against the default provider' do
      let(:coin) { create(:midas_coin, currency_minor: 2999, currency_code: 'USD') }

      it 'raises ArgumentError' do
        expect { coin.convert_to('EUR', at: 3.months.ago) }
          .to raise_error(ArgumentError, /historical/i)
      end
    end

    context 'with a zero-valued coin' do
      let(:coin) { create(:midas_coin, currency_minor: 0, currency_code: 'USD') }

      it 'returns a zero-valued result without calling the provider' do
        result = coin.convert_to('EUR')

        expect(result.currency_minor).to eq(0)
        expect(result.currency_code).to eq('EUR')
      end

      it 'records rate 0 on the Exchange row' do
        coin.convert_to('EUR')

        expect(WhittakerTech::Midas::Exchange.last.rate).to eq(0)
      end
    end

    context 'with a using: provider override' do
      let(:coin) { create(:midas_coin, currency_minor: 1000, currency_code: 'USD') }
      let(:provider) do
        instance_double(WhittakerTech::Midas::Coin::Converter::BankProvider,
                        exchange: Money.new(500, 'EUR'), name: 'custom-provider')
      end

      it 'invokes the provider instead of Money.default_bank' do
        result = coin.convert_to('EUR', using: provider)

        expect(provider).to have_received(:exchange).with(coin.amount, 'EUR')
        expect(result.currency_minor).to eq(500)
      end

      it 'records the provider name as Exchange#source' do
        coin.convert_to('EUR', using: provider)

        expect(WhittakerTech::Midas::Exchange.last.source).to eq('custom-provider')
      end
    end
  end

  describe '#format' do
    let(:coin) { create(:midas_coin, currency_minor: 2999, currency_code: 'USD') }

    it 'returns a formatted string in the target currency' do
      expect(coin.format(to: 'EUR')).to be_a(String)
    end

    it 'performs a live conversion, recording a new Exchange row' do
      expect { coin.format(to: 'EUR') }.to change(WhittakerTech::Midas::Exchange, :count).by(1)
    end
  end
end
