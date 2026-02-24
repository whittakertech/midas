# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Coin::Bidi do
  let(:coin) { WhittakerTech::Midas::Coin.value(2999, 'USD') }

  after { WhittakerTech::Midas.reset_configuration! }

  describe 'Unicode constants' do
    it 'LRI has the correct codepoint (U+2066)' do
      expect(described_class::LRI).to eq("\u2066")
    end

    it 'RLI has the correct codepoint (U+2067)' do
      expect(described_class::RLI).to eq("\u2067")
    end

    it 'PDI has the correct codepoint (U+2069)' do
      expect(described_class::PDI).to eq("\u2069")
    end
  end

  describe '#bidi_isolate' do
    it 'wraps text with LRI and PDI for :ltr' do
      result = coin.bidi_isolate('hello', dir: :ltr)
      expect(result).to eq("\u2066hello\u2069")
    end

    it 'wraps text with RLI and PDI for :rtl' do
      result = coin.bidi_isolate('hello', dir: :rtl)
      expect(result).to eq("\u2067hello\u2069")
    end

    it 'returns text unchanged when dir is nil' do
      expect(coin.bidi_isolate('hello', dir: nil)).to eq('hello')
    end

    it 'returns empty string for nil text' do
      expect(coin.bidi_isolate(nil, dir: :ltr)).to eq('')
    end

    it 'raises ArgumentError for unknown dir' do
      expect { coin.bidi_isolate('hello', dir: :unknown) }.to raise_error(ArgumentError)
    end
  end

  describe '#bidi_isolate_number' do
    it 'wraps number string with LRI and PDI' do
      result = coin.bidi_isolate_number('1234')
      expect(result).to eq("\u20661234\u2069")
    end
  end

  describe '#bidi_currency_dir' do
    it 'returns :ltr by default' do
      expect(coin.bidi_currency_dir('USD')).to eq(:ltr)
    end

    it 'returns configured direction for a currency' do
      WhittakerTech::Midas.currency_directions['ILS'] = :rtl
      expect(coin.bidi_currency_dir('ILS')).to eq(:rtl)
    end
  end
end
