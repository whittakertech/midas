# frozen_string_literal: true

# An association for Coins to be tested on
class TestOrder < ApplicationRecord
  include WhittakerTech::Midas::Bankable

  has_coins :subtotal, :tax, :total
end
