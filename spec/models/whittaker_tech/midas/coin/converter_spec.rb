# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Coin::Converter do
  let(:coin) { WhittakerTech::Midas::Coin.value(2999, 'USD') }

  describe '#convert_to' do
    it 'raises NotImplementedError (placeholder — not yet implemented)' do
      expect { coin.convert_to('EUR') }.to raise_error(NotImplementedError)
    end
  end
end
