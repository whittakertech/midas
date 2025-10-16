# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Bankable do
  let(:order) { TestOrder.create! }

  describe '.has_coin' do
    it 'creates coin association accessor' do
      expect(order).to respond_to(:subtotal)
      expect(order).to respond_to(:subtotal_coin)
    end

    it 'creates amount accessor' do
      expect(order).to respond_to(:subtotal_amount)
    end

    it 'creates format accessor' do
      expect(order).to respond_to(:subtotal_format)
    end

    it 'creates currency conversion accessor' do
      expect(order).to respond_to(:subtotal_in)
    end

    it 'creates setter method' do
      expect(order).to respond_to(:set_subtotal)
    end
  end

  describe '.has_coins' do
    it 'creates accessors for multiple coins' do
      expect(order).to respond_to(:subtotal, :tax, :total)
      expect(order).to respond_to(:set_subtotal, :set_tax, :set_total)
    end
  end

  describe '#set_{coin_name}' do
    context 'with Money object' do
      it 'creates and persists a coin' do
        money = Money.new(1999, 'USD')
        coin = order.set_subtotal(amount: money, currency_code: 'USD')

        expect(coin).to be_persisted
        expect(coin.currency_minor).to eq(1999)
        expect(coin.currency_code).to eq('USD')
      end
    end

    context 'with integer (cents)' do
      it 'creates coin with integer value' do
        coin = order.set_subtotal(amount: 2500, currency_code: 'EUR')

        expect(coin.currency_minor).to eq(2500)
        expect(coin.currency_code).to eq('EUR')
      end
    end

    context 'with float (dollars)' do
      it 'converts float to cents' do
        coin = order.set_subtotal(amount: 19.99, currency_code: 'USD')

        expect(coin.currency_minor).to eq(1999)
        expect(coin.currency_code).to eq('USD')
      end
    end

    context 'with invalid amount' do
      it 'raises ArgumentError' do
        expect {
          order.set_subtotal(amount: 'invalid', currency_code: 'USD')
        }.to raise_error(ArgumentError, /Invalid value for subtotal/)
      end
    end

    context 'when coin already exists' do
      before do
        order.set_subtotal(amount: 1000, currency_code: 'USD')
      end

      it 'updates existing coin' do
        expect {
          order.set_subtotal(amount: 2000, currency_code: 'USD')
        }.not_to change(WhittakerTech::Midas::Coin, :count)

        expect(order.subtotal.currency_minor).to eq(2000)
      end
    end
  end

  describe 'coin_name_amount' do
    it 'returns nil when coin does not exist' do
      expect(order.subtotal_amount).to be_nil
    end

    it 'returns Money object when coin exists' do
      order.set_subtotal(amount: 1500, currency_code: 'USD')

      amount = order.subtotal_amount
      expect(amount).to be_a(Money)
      expect(amount.cents).to eq(1500)
    end
  end

  describe 'coin_name_format' do
    it 'returns nil when coin does not exist' do
      expect(order.subtotal_format).to be_nil
    end

    it 'returns formatted string when coin exists' do
      order.set_subtotal(amount: 1999, currency_code: 'USD')

      formatted = order.subtotal_format
      expect(formatted).to be_a(String)
      expect(formatted).to include('19.99')
    end
  end

  describe 'coin_name_in' do
    before do
      order.set_subtotal(amount: 1000, currency_code: 'USD')
      Money.default_bank.add_rate('USD', 'EUR', 0.85)
    end

    after do
      Money.default_bank.rates.clear
    end

    it 'returns nil when coin does not exist' do
      order_without_tax = TestOrder.create!
      expect(order_without_tax.tax_in('EUR')).to be_nil
    end

    it 'returns formatted amount in converted currency' do
      converted = order.subtotal_in('EUR')

      expect(converted).to be_a(String)
      expect(converted).to include('8.50')
    end
  end

  describe 'association behavior' do
    it 'creates coin with correct resource_label' do
      order.set_subtotal(amount: 100, currency_code: 'USD')

      expect(order.subtotal.resource_label).to eq('subtotal')
    end

    it 'associates coin with correct resource' do
      order.set_tax(amount: 200, currency_code: 'USD')

      expect(order.tax.resource).to eq(order)
    end

    it 'can have multiple coins on same resource' do
      order.set_subtotal(amount: 1000, currency_code: 'USD')
      order.set_tax(amount: 100, currency_code: 'USD')
      order.set_total(amount: 1100, currency_code: 'USD')

      expect(order.reload.midas_coins.count).to eq(3)
    end
  end

  describe 'dependent destroy' do
    it 'destroys coins when resource is destroyed' do
      order.set_subtotal(amount: 100, currency_code: 'USD')
      coin_id = order.subtotal.id

      expect {
        order.destroy!
      }.to change(WhittakerTech::Midas::Coin, :count).by(-1)

      expect(WhittakerTech::Midas::Coin.find_by(id: coin_id)).to be_nil
    end
  end
end