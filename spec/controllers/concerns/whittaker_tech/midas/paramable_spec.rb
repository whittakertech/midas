# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Paramable do
  subject(:host) do
    Class.new { include WhittakerTech::Midas::Paramable }.new
  end

  describe '#coin_permit_keys' do
    it 'returns combined and split keys for each role' do
      expect(host.coin_permit_keys(:subtotal, :tax)).to contain_exactly(
        :subtotal, :subtotal_minor, :subtotal_currency,
        :tax, :tax_minor, :tax_currency
      )
    end

    it 'handles a single role' do
      expect(host.coin_permit_keys(:tax)).to contain_exactly(:tax, :tax_minor, :tax_currency)
    end
  end

  describe '#assign_coins' do
    let(:record) { instance_double(TestOrder) }

    context 'with combined format' do
      it 'calls set_subtotal with parsed minor units and currency' do
        allow(record).to receive(:set_subtotal).with(amount: 1245, currency_code: 'USD')
        host.assign_coins(record, { subtotal: '1245:USD' }, :subtotal)
        expect(record).to have_received(:set_subtotal).with(amount: 1245, currency_code: 'USD')
      end

      it 'upcases a lowercase currency code' do
        allow(record).to receive(:set_subtotal).with(amount: 1245, currency_code: 'USD')
        host.assign_coins(record, { subtotal: '1245:usd' }, :subtotal)
        expect(record).to have_received(:set_subtotal).with(amount: 1245, currency_code: 'USD')
      end

      it 'supports negative minor units' do
        allow(record).to receive(:set_subtotal).with(amount: -500, currency_code: 'EUR')
        host.assign_coins(record, { subtotal: '-500:EUR' }, :subtotal)
        expect(record).to have_received(:set_subtotal).with(amount: -500, currency_code: 'EUR')
      end

      it 'handles zero minor units' do
        allow(record).to receive(:set_subtotal).with(amount: 0, currency_code: 'JPY')
        host.assign_coins(record, { subtotal: '0:JPY' }, :subtotal)
        expect(record).to have_received(:set_subtotal).with(amount: 0, currency_code: 'JPY')
      end

      it 'strips surrounding whitespace from the value' do
        allow(record).to receive(:set_subtotal).with(amount: 100, currency_code: 'GBP')
        host.assign_coins(record, { subtotal: '  100:GBP  ' }, :subtotal)
        expect(record).to have_received(:set_subtotal).with(amount: 100, currency_code: 'GBP')
      end
    end

    context 'with split format' do
      it 'calls set_subtotal from minor + currency fields' do
        allow(record).to receive(:set_subtotal).with(amount: 1245, currency_code: 'USD')
        host.assign_coins(record, { subtotal_minor: 1245, subtotal_currency: 'USD' }, :subtotal)
        expect(record).to have_received(:set_subtotal).with(amount: 1245, currency_code: 'USD')
      end

      it 'coerces string minor units to integer' do
        allow(record).to receive(:set_subtotal).with(amount: 1245, currency_code: 'USD')
        host.assign_coins(record, { subtotal_minor: '1245', subtotal_currency: 'USD' }, :subtotal)
        expect(record).to have_received(:set_subtotal).with(amount: 1245, currency_code: 'USD')
      end

      it 'upcases a lowercase currency code' do
        allow(record).to receive(:set_subtotal).with(amount: 500, currency_code: 'EUR')
        host.assign_coins(record, { subtotal_minor: 500, subtotal_currency: 'eur' }, :subtotal)
        expect(record).to have_received(:set_subtotal).with(amount: 500, currency_code: 'EUR')
      end
    end

    context 'when combined format takes priority over split' do
      it 'uses combined when both are present' do
        allow(record).to receive(:set_subtotal).with(amount: 1245, currency_code: 'USD')
        host.assign_coins(record, { subtotal: '1245:USD', subtotal_minor: 999, subtotal_currency: 'EUR' }, :subtotal)
        expect(record).to have_received(:set_subtotal).with(amount: 1245, currency_code: 'USD')
      end
    end

    context 'with absent params' do
      before { allow(record).to receive(:set_subtotal) }

      it 'skips the role when no params are present' do
        host.assign_coins(record, {}, :subtotal)
        expect(record).not_to have_received(:set_subtotal)
      end

      it 'skips when only minor is present' do
        host.assign_coins(record, { subtotal_minor: 1245 }, :subtotal)
        expect(record).not_to have_received(:set_subtotal)
      end

      it 'skips when only currency is present' do
        host.assign_coins(record, { subtotal_currency: 'USD' }, :subtotal)
        expect(record).not_to have_received(:set_subtotal)
      end

      it 'processes other roles even when one is absent' do
        allow(record).to receive(:set_tax).with(amount: 500, currency_code: 'USD')
        host.assign_coins(record, { tax_minor: 500, tax_currency: 'USD' }, :subtotal, :tax)
        expect(record).not_to have_received(:set_subtotal)
        expect(record).to have_received(:set_tax)
      end
    end

    context 'with invalid combined format' do
      before { allow(record).to receive(:set_subtotal) }

      it 'skips when there is no colon separator' do
        host.assign_coins(record, { subtotal: '1245' }, :subtotal)
        expect(record).not_to have_received(:set_subtotal)
      end

      it 'skips when the currency code is not 3 letters' do
        host.assign_coins(record, { subtotal: '1245:USDX' }, :subtotal)
        expect(record).not_to have_received(:set_subtotal)
      end

      it 'skips when the minor units contain a decimal point' do
        host.assign_coins(record, { subtotal: '29.99:USD' }, :subtotal)
        expect(record).not_to have_received(:set_subtotal)
      end

      it 'skips a blank string' do
        host.assign_coins(record, { subtotal: '' }, :subtotal)
        expect(record).not_to have_received(:set_subtotal)
      end
    end

    context 'with multiple roles' do
      it 'processes all roles in a single call' do
        allow(record).to receive(:set_subtotal).with(amount: 1245, currency_code: 'USD')
        allow(record).to receive(:set_tax).with(amount: 500, currency_code: 'EUR')
        host.assign_coins(
          record,
          { subtotal: '1245:USD', tax_minor: 500, tax_currency: 'EUR' },
          :subtotal, :tax
        )
        expect(record).to have_received(:set_subtotal)
        expect(record).to have_received(:set_tax)
      end
    end
  end
end
