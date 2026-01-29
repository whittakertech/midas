# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Coin::Allocation do
  let(:coin) { WhittakerTech::Midas::Coin.value(3_359, 'USD') } # $33.59

  describe 'construction' do
    it 'requires a Coin' do
      expect do
        described_class.new(coin: 'nope', divisor: 10, rounding_policy: :round)
      end.to raise_error(TypeError)
    end

    it 'requires a positive divisor' do
      expect do
        described_class.new(coin:, divisor: 0, rounding_policy: :round)
      end.to raise_error(TypeError)
    end

    it 'requires a known rounding policy' do
      expect do
        described_class.new(coin:, divisor: 10, rounding_policy: :unknown)
      end.to raise_error(ArgumentError)
    end
  end

  describe '#value' do
    it 'returns a Coin' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :round)

      expect(allocator.value).to be_a(WhittakerTech::Midas::Coin)
    end

    it 'applies rounding policy correctly' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :round)

      expect(allocator.value.currency_minor).to eq(336) # 335.9 → 336
    end

    it 'never mutates the original coin' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :floor)

      allocator.value
      expect(coin.currency_minor).to eq(3_359)
    end
  end

  describe '#price' do
    it 'returns a Coin' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :round)

      expect(allocator.price(qty: 5)).to be_a(WhittakerTech::Midas::Coin)
    end

    it 'scales linearly from per-subunit value' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :round)

      expect(allocator.price(qty: 10).currency_minor).to eq(3_359)
    end

    it 'rejects negative quantities' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :round)

      expect do
        allocator.price(qty: -1)
      end.to raise_error(ArgumentError)
    end

    it 'does not compound rounding across quantity' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :round)

      per_unit = allocator.value.currency_minor # 336
      total    = allocator.price(qty: 10).currency_minor

      expect(per_unit * 10).to eq(3_360)
      expect(total).to eq(3_359)
    end
  end

  describe '#inspect' do
    it 'includes the underlying coin' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :round)
      expect(allocator.inspect).to include(coin.inspect)
    end

    it 'includes the divisor' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :round)
      expect(allocator.inspect).to include('divisor=10')
    end

    it 'includes the rounding policy' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :round)
      expect(allocator.inspect).to include('rounding_policy=round')
    end
  end

  describe 'immutability' do
    it 'freezes the underlying coin reference' do
      allocator = described_class.new(coin:, divisor: 10, rounding_policy: :round)
      expect(allocator.coin).to be_frozen
    end
  end
end
