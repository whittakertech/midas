# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::FormHelper do
  let(:order) { TestOrder.create! }

  describe '#midas_currency_field' do
    let(:form_builder) { instance_double(ActionView::Helpers::FormBuilder, object: order, object_name: 'test_order') }

    before do
      allow(helper).to receive(:render).and_return('<rendered partial>')
    end

    it 'renders the currency field partial' do
      helper.midas_currency_field(form_builder, :subtotal, currency_code: 'USD')

      expect(helper).to have_received(:render).with(
        partial: 'whittaker_tech/midas/shared/currency_field',
        locals: hash_including(
          form: form_builder,
          attribute: :subtotal,
          currency_code: 'USD',
          decimals: 2
        )
      )
    end

    it 'uses current coin value if exists' do
      order.set_subtotal(amount: 1999, currency_code: 'USD')

      helper.midas_currency_field(form_builder, :subtotal, currency_code: 'USD')

      expect(helper).to have_received(:render).with(
        partial: 'whittaker_tech/midas/shared/currency_field',
        locals: hash_including(current_minor: 1999)
      )
    end

    it 'defaults to 0 if no coin exists' do
      helper.midas_currency_field(form_builder, :subtotal, currency_code: 'USD')

      expect(helper).to have_received(:render).with(
        partial: 'whittaker_tech/midas/shared/currency_field',
        locals: hash_including(current_minor: 0)
      )
    end

    it 'passes through input_html options' do
      helper.midas_currency_field(
        form_builder,
        :subtotal,
        currency_code: 'USD',
        input_html: { class: 'custom-input' }
      )

      expect(helper).to have_received(:render).with(
        partial: 'whittaker_tech/midas/shared/currency_field',
        locals: hash_including(
          input_html: { class: 'custom-input' }
        )
      )
    end

    it 'passes through wrapper_html options' do
      helper.midas_currency_field(
        form_builder,
        :subtotal,
        currency_code: 'USD',
        wrapper_html: { class: 'form-group' }
      )

      expect(helper).to have_received(:render).with(
        partial: 'whittaker_tech/midas/shared/currency_field',
        locals: hash_including(
          wrapper_html: { class: 'form-group' }
        )
      )
    end

    it 'supports custom decimal places' do
      helper.midas_currency_field(
        form_builder,
        :subtotal,
        currency_code: 'JPY',
        decimals: 0
      )

      expect(helper).to have_received(:render).with(
        partial: 'whittaker_tech/midas/shared/currency_field',
        locals: hash_including(decimals: 0)
      )
    end

    it 'passes through label text' do
      helper.midas_currency_field(
        form_builder,
        :subtotal,
        currency_code: 'USD',
        label: 'Order Subtotal'
      )

      expect(helper).to have_received(:render).with(
        partial: 'whittaker_tech/midas/shared/currency_field',
        locals: hash_including(label_text: 'Order Subtotal')
      )
    end
  end
end
