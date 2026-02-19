# Examples

Practical, end-to-end usage examples.

---

## E-commerce product pricing

```ruby
class Product < ApplicationRecord
  include WhittakerTech::Midas::Bankable

  has_coins :price, :cost, :msrp
end
```

```ruby
product = Product.create!(name: 'Wireless Headphones')

product.set_price(amount: 79.99, currency_code: 'USD')
product.set_cost(amount:  32.50, currency_code: 'USD')
product.set_msrp(amount:  99.99, currency_code: 'USD')

product.price_format  # => "$79.99"
product.cost_format   # => "$32.50"
product.msrp_format   # => "$99.99"

# Margin calculation
margin = product.price - product.cost  # => Coin($47.49)
margin.present('%s%M (%c)')            # => "$47.49 (USD)"

# Discount from MSRP
discount = product.msrp - product.price  # => Coin($20.00)
```

---

## Invoice with multiple line items

```ruby
class Invoice < ApplicationRecord
  include WhittakerTech::Midas::Bankable

  has_coins :subtotal, :tax, :shipping, :total
end
```

```ruby
invoice = Invoice.create!(number: 'INV-001')

invoice.set_subtotal(amount: 250.00, currency_code: 'USD')
invoice.set_tax(amount:       20.00, currency_code: 'USD')
invoice.set_shipping(amount:   9.99, currency_code: 'USD')
invoice.set_total(amount:    279.99, currency_code: 'USD')

# Verify total matches components
components = invoice.subtotal + invoice.tax + invoice.shipping
components == invoice.total  # => true

invoice.midas_coins.count    # => 4
```

---

## Per-unit pricing with Allocation

Use `Allocation` when you have a bulk price and need per-unit cost:

```ruby
# A pack of 6 sells for $15.00
six_pack = Coin.value(1500, 'USD')
alloc = six_pack.allocate(per: 6, rounding_policy: :ceil)

alloc.value           # => Coin($2.50)    — per unit
alloc.price(qty: 1)   # => Coin($2.50)
alloc.price(qty: 3)   # => Coin($7.50)
alloc.price(qty: 6)   # => Coin($15.00)  — reconstitutes original exactly
```

When pricing does not divide evenly:

```ruby
# $10.00 split across 3 units
coin = Coin.value(1000, 'USD')

coin.divide_round(3)    # => Coin($3.33)
coin.divide_ceil(3)     # => Coin($3.34)  ← captures the lost cent
coin.divide_floor(3)    # => Coin($3.33)
coin.divide_bankers(3)  # => Coin($3.33)
```

---

## Currency input form

Bank-style field that accumulates digits from the right:

```erb
<%# app/views/products/_form.html.erb %>
<%= form_with model: @product do |f| %>
  <div class="field">
    <%= f.label :price %>
    <%= midas_currency_field f, :price,
          currency_code: 'USD',
          input_html: { class: 'currency-input text-right' } %>
  </div>

  <%= f.submit 'Save Product' %>
<% end %>
```

Controller:

```ruby
class ProductsController < ApplicationController
  def create
    @product = Product.new
    @product.save!
    @product.set_price(
      amount:        params[:product][:price_minor].to_i,
      currency_code: params[:product][:price_currency]
    )
    redirect_to @product
  end
end
```

---

## Mixed-currency display

```ruby
class Order < ApplicationRecord
  include WhittakerTech::Midas::Bankable

  has_coins :subtotal, :shipping
end

order = Order.create!
order.set_subtotal(amount: 100_00, currency_code: 'USD')   # $100.00
order.set_shipping(amount:  1_500, currency_code: 'GBP')   # £15.00

order.subtotal_format   # => "$100.00"
order.shipping_format   # => "£15.00"
```

---

## Presenter formatting patterns

```ruby
coin = Coin.value(2999, 'USD')

coin.present('%t')                   # => "$29.99"
coin.present('%s%M')                 # => "$29.99"
coin.present('%M %c')                # => "29.99 USD"
coin.present('%m minor units')       # => "2999 minor units"
coin.present('~%t', approx: true)    # => "≈$29.99"
coin.present('%M %u', units: '/mo')  # => "29.99 /mo"
coin.present('Total: %t (%c)')       # => "Total: $29.99 (USD)"
coin.present('%%off: %n')            # => "%off: 29.99"
```

---

## Arithmetic pipeline

```ruby
items = [
  Coin.value(1999, 'USD'),   # $19.99
  Coin.value(999,  'USD'),   # $9.99
  Coin.value(2499, 'USD')    # $24.99
]

# Sum all items
subtotal = items.reduce(:+)   # => Coin($54.97)

# Apply 10% discount
discount = subtotal.divide(10, rounding_policy: :floor)   # => Coin($5.49)
after_discount = subtotal - discount                       # => Coin($49.48)

# Tax at 8.5%
tax = after_discount.divide(100, rounding_policy: :round) * 9  # approximate 8.5%
total = after_discount + tax
```

---

## Zero-value guard

Bankable returns `nil` until a coin is first set. Guard before arithmetic:

```ruby
ZERO_USD = Coin.zero('USD')

subtotal = order.subtotal || ZERO_USD
tax      = order.tax      || ZERO_USD
total    = subtotal + tax
```

---

## Set membership and deduplication

Coins implement `eql?` and `hash` for value-based identity:

```ruby
prices = Set.new

prices << Coin.value(999, 'USD')
prices << Coin.value(999, 'USD')  # duplicate — not added
prices << Coin.value(999, 'EUR')  # different currency — added

prices.size  # => 2
```

---

## RTL currency display (Arabic / Hebrew UI)

Configure RTL currencies in an initializer:

```ruby
# config/initializers/midas.rb
WhittakerTech::Midas.currency_directions['ILS'] = :rtl
WhittakerTech::Midas.currency_directions['AED'] = :rtl
```

Presenter tokens automatically wrap output in the correct Unicode isolation
marks. No template changes required.

```ruby
coin = Coin.value(10000, 'ILS')   # ₪100.00
coin.present('%s%M')
# => "\u2067₪\u2069\u2066100.00\u2069"  (RLI + symbol + PDI + LRI + number + PDI)
```

---

## Coin parsing from heterogeneous sources

```ruby
# All produce Coin(2999 USD)
Coin.parse(Money.new(2999, 'USD'))
Coin.parse(29.99, currency_code: 'USD')
Coin.parse('29.99', currency_code: 'USD')
Coin.parse('$29.99')

# Coin is returned as-is
existing = Coin.value(2999, 'USD')
Coin.parse(existing) == existing   # => true
```

---

## Factory pattern for tests

```ruby
# spec/factories/wt_midas_coins.rb
FactoryBot.define do
  factory :midas_coin, class: 'WhittakerTech::Midas::Coin' do
    resource_label  { 'price' }
    currency_code   { 'USD' }
    currency_minor  { 2999 }
    association :resource, factory: :product
  end
end

# In specs:
coin = build(:midas_coin, currency_minor: 5000)
coin.major   # => BigDecimal("50.00")
```
