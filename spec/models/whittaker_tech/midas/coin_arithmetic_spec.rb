# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Coin do
  let(:usd_ten)  { described_class.value(1000, 'USD') }
  let(:usd_five) { described_class.value(500, 'USD') }
  let(:eur_ten)  { described_class.value(1000, 'EUR') }

  describe 'equality' do
    it 'considers coins equal with same currency and minor value' do
      expect(usd_ten).to eq(described_class.value(1000, 'USD'))
    end

    it 'distinguishes coins with different currencies' do
      expect(usd_ten).not_to eq(eur_ten)
    end

    it 'equal coins produce the same hash value' do
      a = described_class.value(1000, 'USD')
      b = described_class.value(1000, 'USD')
      expect(a.hash).to eq(b.hash)
    end

    it 'eql? coins are usable as Hash keys' do
      a = described_class.value(1000, 'USD')
      b = described_class.value(1000, 'USD')
      h = { a => 'found' }
      expect(h[b]).to eq('found')
    end
  end

  describe 'exact arithmetic' do
    it 'adds coins of the same currency' do
      expect(usd_ten + usd_five).to eq(
        described_class.value(1500, 'USD')
      )
    end

    it 'rejects mixed currencies' do
      expect { usd_ten + eur_ten }.to raise_error(ArgumentError)
      expect { usd_ten - eur_ten }.to raise_error(ArgumentError)
    end

    it 'subtracts coins of the same currency' do
      expect(usd_ten - usd_five).to eq(
        described_class.value(500, 'USD')
      )
    end

    it 'supports integer multiplication only' do
      expect(usd_five * 3).to eq(
        described_class.value(1500, 'USD')
      )
    end

    it 'rejects fractional multiplication' do
      expect { usd_five * 1.5 }.to raise_error(TypeError)
    end
  end

  describe 'remainder arithmetic' do
    it 'returns remainder as a Coin' do
      expect(usd_ten % 300).to eq(
        described_class.value(100, 'USD')
      )
    end

    it 'rejects non-integer divisors' do
      expect { usd_ten % 2.5 }.to raise_error(TypeError)
    end

    it 'returns a frozen Coin' do
      expect(usd_ten % 300).to be_frozen
    end
  end

  describe 'negation' do
    it 'supports unary negation' do
      expect(-usd_five).to eq(
        described_class.value(-500, 'USD')
      )
    end

    it 'negate returns a frozen Coin' do
      expect(usd_five.negate).to be_frozen
    end

    it '-@ returns a frozen Coin' do
      expect(-usd_five).to be_frozen
    end
  end

  describe 'division with policy' do
    it 'defaults to round policy' do
      expect(usd_ten.divide(3)).to eq(
        described_class.value(333, 'USD')
      )
    end

    it 'supports explicit rounding policy' do
      expect(
        usd_ten.divide(3, rounding_policy: :ceil)
      ).to eq(
        described_class.value(334, 'USD')
      )
    end

    it 'falls back to default rounding policy and warns developer when policy is invalid' do
      expect do
        result = usd_ten.divide(3, rounding_policy: :unknown)

        expect(result).to eq(
          described_class.value(333, 'USD')
        )
      end.to output(/Unknown rounding mode/).to_stderr
    end

    it 'floor truncates toward zero (1000 / 3 => 333)' do
      expect(usd_ten.divide(3, rounding_policy: :floor)).to eq(
        described_class.value(333, 'USD')
      )
    end

    it 'bankers rounds half-to-even (5 / 2 => 2)' do
      coin = described_class.value(5, 'USD')
      expect(coin.divide(2, rounding_policy: :bankers)).to eq(
        described_class.value(2, 'USD')
      )
    end

    it 'bankers rounds half-to-even (3 / 2 => 2)' do
      coin = described_class.value(3, 'USD')
      expect(coin.divide(2, rounding_policy: :bankers)).to eq(
        described_class.value(2, 'USD')
      )
    end
  end

  describe 'immutability' do
    it 'returns frozen Coins' do
      expect(usd_five * 2).to be_frozen
    end

    it 'operations on frozen input Coins work correctly' do
      frozen_coin = described_class.value(1000, 'USD').freeze
      expect(frozen_coin + usd_five).to eq(described_class.value(1500, 'USD'))
    end

    it '* 0 returns a zero Coin' do
      multiplier = 0
      expect(usd_five * multiplier).to eq(described_class.value(0, 'USD'))
    end

    it '+ zero_coin equals self' do
      zero = described_class.value(0, 'USD')
      expect(usd_ten + zero).to eq(usd_ten)
    end
  end

  describe 'dynamically generated divisors' do
    it 'creates a method for each rounding method' do
      coin = described_class.value(1000, 'USD')

      WhittakerTech::Midas::ROUNDING_POLICIES.each_key do |key|
        expect(coin).to respond_to("divide_#{key}")
      end
    end

    it 'each generated divide_* method returns a Coin' do
      coin = described_class.value(1000, 'USD')

      WhittakerTech::Midas::ROUNDING_POLICIES.each_key do |key|
        result = coin.public_send("divide_#{key}", 3)
        expect(result).to be_a(described_class)
      end
    end
  end
end
