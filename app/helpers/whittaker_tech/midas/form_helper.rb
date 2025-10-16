# frozen_string_literal: true

module WhittakerTech
  module Midas
    # Form helper for rendering currency input fields with bank-style typing behavior.
    #
    # This helper provides a headless currency input that the parent application
    # can style according to its design system. The helper only provides the
    # behavior (via Stimulus) and basic structure.
    #
    # @example Basic usage (unstyled)
    #   <%= midas_currency_field f, :price, currency_code: 'USD' %>
    #
    # @example With Tailwind styling
    #   <%= midas_currency_field f, :price,
    #         currency_code: 'USD',
    #         input_html: { class: 'rounded-lg border-gray-300 text-right' },
    #         wrapper_html: { class: 'mb-4' },
    #         label: 'Product Price' %>
    #
    # @example With Bootstrap styling
    #   <%= midas_currency_field f, :price,
    #         currency_code: 'EUR',
    #         input_html: { class: 'form-control text-end' },
    #         wrapper_html: { class: 'mb-3' },
    #         label: 'Price (€)' %>
    module FormHelper
      # Renders a currency input field with bank-style typing behavior.
      #
      # The field consists of:
      # - A visible formatted input (displays dollars/euros)
      # - A hidden input storing minor units (cents)
      # - A hidden input storing the currency code
      #
      # @param form [ActionView::Helpers::FormBuilder] The form builder
      # @param attribute [Symbol] The coin attribute name (e.g., :price, :cost)
      # @param currency_code [String] ISO 4217 currency code (e.g., 'USD', 'EUR')
      # @param options [Hash] Additional options
      # @option options [Hash] :input_html HTML attributes for the display input
      # @option options [Hash] :wrapper_html HTML attributes for the wrapper div
      # @option options [Integer] :decimals Number of decimal places (default: 2)
      # @option options [String] :label Label text (optional, no label if nil)
      #
      # @return [String] Rendered HTML for the currency field
      #
      # @example
      #   <%= midas_currency_field f, :price,
      #         currency_code: 'USD',
      #         decimals: 2,
      #         label: 'Sale Price',
      #         wrapper_html: { class: 'form-group' },
      #         input_html: { class: 'form-control', placeholder: '0.00' } %>
      def midas_currency_field(form, attribute, currency_code:, **options)
        input_html = options.fetch(:input_html, {})
        wrapper_html = options.fetch(:wrapper_html, {})
        decimals = options.fetch(:decimals, 2)
        label_text = options.fetch(:label, nil)

        # Get current value if coin exists
        resource = form.object
        coin = resource.public_send(attribute) if resource.respond_to?(attribute)
        current_minor = coin&.currency_minor || 0

        render partial: 'whittaker_tech/midas/shared/currency_field',
               locals: {
                 form: form,
                 attribute: attribute,
                 currency_code: currency_code,
                 current_minor: current_minor,
                 decimals: decimals,
                 input_html: input_html,
                 wrapper_html: wrapper_html,
                 label_text: label_text
               }
      end
    end
  end
end
