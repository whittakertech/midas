# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Coin::Presenter do
  let(:coin) { WhittakerTech::Midas::Coin.value(1_234, 'USD') }

  it 'renders major units with symbol' do
    result = coin.present('%s%M.%m')
    expect(result).to include('$')
    expect(result).to include('12')
  end

  it 'renders currency code token' do
    expect(coin.present('%c')).to include('USD')
  end

  it 'renders literal percent' do
    expect(coin.present('%%')).to eq('%')
  end

  it 'raises on unknown token' do
    expect { coin.present('%x') }.to raise_error(ArgumentError)
  end

  it 'renders total formatted amount (%t)' do
    output = coin.present('%t')
    expect(output).to include('$')
    expect(output).to include('12')
  end

  it 'renders numeric portion only (%n)' do
    output = coin.present('%n')
    expect(output).to include('12')
    expect(output).not_to include('$')
  end

  it 'renders units when provided (%u)' do
    output = coin.present('%u', units: 'kg')
    expect(output).to eq('kg')
  end

  it 'renders per-exact text when provided (%p)' do
    output = coin.present('%p', per_exact: 'per item')
    expect(output).to eq('per item')
  end

  it 'renders approximation symbol when enabled (%~)' do
    output = coin.present('%~', approx: true)
    expect(output).to eq('≈')
  end

  it 'renders nothing for optional tokens when not provided' do
    output = coin.present('%u%p%~')
    expect(output).to eq('')
  end
end
