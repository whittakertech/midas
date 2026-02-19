# frozen_string_literal: true

FactoryBot.define do
  factory :midas_coin, class: 'WhittakerTech::Midas::Coin' do
    resource_role { 'subtotal' }
    currency_code { 'USD' }
    currency_minor { 1295 }

    resource factory: %i[test_order]
  end

  factory :test_order
end
