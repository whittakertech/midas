# frozen_string_literal: true

# Paramable provides Strong Params integration for Bankable coin attributes.
#
# Mix into any controller that needs to permit and apply coin parameters.
# Accepts two input formats per role:
#
# **Combined** — one field, colon-delimited minor units and ISO currency code:
#
#   price: "1245:USD"
#
# **Split** — two fields, minor units and currency code separately:
#
#   price_minor: 1245, price_currency: "USD"
#
# Both formats coerce to the same `set_*` call on the record. The combined
# format is convenient for JSON APIs; the split format matches what
# `midas_currency_field` emits from the browser.
#
# @example
#   class ProductsController < ApplicationController
#     include WhittakerTech::Midas::Paramable
#
#     def create
#       @product = Product.new(product_params.except(*coin_permit_keys(:price, :cost)))
#       @product.save!
#       assign_coins(@product, product_params, :price, :cost)
#     end
#
#     private
#
#     def product_params
#       params.require(:product).permit(:name, *coin_permit_keys(:price, :cost))
#     end
#   end
#
# @since 0.3.0
module WhittakerTech::Midas::Paramable
  extend ActiveSupport::Concern

  COMBINED_PATTERN = /\A(-?\d+):([A-Za-z]{3})\z/

  # Returns the list of param field names to pass to ActionController::Parameters#permit
  # for the given coin roles. Always includes keys for both formats so either works.
  #
  # @param roles [Array<Symbol>]
  # @return [Array<Symbol>]
  #
  # @example
  #   coin_permit_keys(:price, :cost)
  #   # => [:price, :price_minor, :price_currency, :cost, :cost_minor, :cost_currency]
  def coin_permit_keys(*roles)
    roles.flat_map { |r| [r.to_sym, :"#{r}_minor", :"#{r}_currency"] }
  end

  # Calls `set_#{role}` on +record+ for each role that has params present.
  # Skips roles whose params are entirely absent; raises nothing for missing data.
  #
  # Combined format takes priority when both formats appear for the same role.
  #
  # @param record [ActiveRecord::Base] a model that includes Bankable
  # @param permitted_params [ActionController::Parameters, Hash]
  # @param roles [Array<Symbol>]
  def assign_coins(record, permitted_params, *roles)
    roles.each do |role|
      data = extract_coin(permitted_params, role)
      record.public_send(:"set_#{role}", **data) if data
    end
  end

  private

  def extract_coin(params, role)
    combined = params[role]
    if combined.present?
      parse_combined_coin(combined.to_s)
    elsif params[:"#{role}_minor"].present? && params[:"#{role}_currency"].present?
      {
        amount: params[:"#{role}_minor"].to_i,
        currency_code: params[:"#{role}_currency"].to_s.upcase
      }
    end
  end

  def parse_combined_coin(value)
    match = COMBINED_PATTERN.match(value.strip)
    return nil unless match

    { amount: match[1].to_i, currency_code: match[2].upcase }
  end
end
