# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Exchange do
  subject(:exchange) { described_class.new(rate: 1, source: 'test', at: Time.current) }

  it { should validate_presence_of(:rate) }
  it { should validate_presence_of(:source) }
  it { should validate_presence_of(:at) }

  describe 'has_coins :from, :to' do
    before do
      exchange.save!
      exchange.set_from(amount: 1000, currency_code: 'USD')
      exchange.set_to(amount: 850, currency_code: 'EUR')
    end

    it 'attaches a from coin via Bankable set_from' do
      expect(exchange.from.currency_code).to eq('USD')
      expect(exchange.from.currency_minor).to eq(1000)
    end

    it 'attaches a to coin via Bankable set_to' do
      expect(exchange.to.currency_code).to eq('EUR')
      expect(exchange.to.currency_minor).to eq(850)
    end

    it 'owns both coins via midas_coins' do
      expect(exchange.midas_coins.count).to eq(2)
    end
  end

  describe 'immutability' do
    before { exchange.save! }

    it 'allows attaching from/to coins after creation' do
      expect { exchange.set_from(amount: 100, currency_code: 'USD') }.not_to raise_error
      expect { exchange.set_to(amount: 85, currency_code: 'EUR') }.not_to raise_error
    end

    it 'blocks updating rate/source/at after creation' do
      expect { exchange.update!(rate: 2) }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { exchange.update!(source: 'other') }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { exchange.update!(at: 1.day.from_now) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'still allows destroy' do
      expect { exchange.destroy! }.not_to raise_error
    end
  end
end
