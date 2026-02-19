# Usage

## The Bankable concern

Include `Bankable` in any ActiveRecord model to give it monetary attributes:

```ruby
class Product < ApplicationRecord
  include WhittakerTech::Midas::Bankable

  has_coins :price, :cost, :msrp
end
```

### `has_coin` and `has_coins`

```ruby
# Single coin
has_coin :price

# Multiple coins at once
has_coins :subtotal, :tax, :shipping, :total

# Custom dependency behaviour
has_coin :deposit, dependent: :nullify
```

`dependent:` accepts any ActiveRecord `has_one` dependency option
(`:destroy`, `:delete`, `:nullify`, `:restrict_with_exception`,
`:restrict_with_error`). Default: `:destroy`.

---

## Generated methods

For every `has_coin :name`, Bankable generates:

| Method                              | Returns              | Notes                                  |
|-------------------------------------|----------------------|----------------------------------------|
| `name`                              | `Coin` or `nil`      | The persisted Coin record              |
| `name_coin`                         | `Coin` or `nil`      | The `has_one` association directly     |
| `name_amount`                       | `Money` or `nil`     | Calls `coin.amount`                    |
| `name_format`                       | `String` or `nil`    | Calls `coin.amount.format`             |
| `set_name(amount:, currency_code:)` | `Coin`               | Creates or updates the Coin            |
| `midas_coins`                       | `ActiveRecord::Relation` | All coins on this resource (shared) |

---

## Setting values

```ruby
product = Product.create!

# From a float (major units — dollars)
product.set_price(amount: 29.99, currency_code: 'USD')

# From a Money object
product.set_price(amount: Money.new(2999, 'USD'), currency_code: 'USD')

# From an integer (minor units — cents)
product.set_price(amount: 2999, currency_code: 'USD')
```

!!! note "Integer vs. Numeric semantics"
    When you pass an `Integer`, it is treated as **minor units** (cents).
    When you pass a `Float` or `BigDecimal`, it is treated as **major units**
    (dollars) and scaled by the currency's decimal places.

---

## Reading values

```ruby
product.price             # => #<WhittakerTech::Midas::Coin ...>
product.price_amount      # => #<Money @fractional=2999 @currency="USD">
product.price_format      # => "$29.99"

product.price.currency_code   # => "USD"
product.price.currency_minor  # => 2999
product.price.major           # => BigDecimal("29.99")
product.price.decimals        # => 2
```

---

## Coin arithmetic

All arithmetic returns new frozen Coins. Coins are never mutated.

### Addition and subtraction

```ruby
a = Coin.value(1000, 'USD')  # $10.00
b = Coin.value(500,  'USD')  # $5.00

a + b   # => Coin($15.00)
a - b   # => Coin($5.00)
-a      # => Coin(-$10.00)
a.negate # same as -a
```

Currencies must match. A mismatched operation raises `ArgumentError`.

### Multiplication and modulo

```ruby
a * 3      # => Coin($30.00)
a % 3      # => Coin($0.01)  # remainder of 1000 % 3 = 1 cent
```

### Division with rounding policies

Integer division can produce a non-integer result. Specify a policy:

```ruby
coin = Coin.value(1000, 'USD')  # $10.00

coin.divide(3, rounding_policy: :round)    # => Coin($3.33)  (333.33 → 333)
coin.divide(3, rounding_policy: :ceil)     # => Coin($3.34)
coin.divide(3, rounding_policy: :floor)    # => Coin($3.33)
coin.divide(3, rounding_policy: :bankers)  # => Coin($3.33)

# Shorthand convenience methods
coin.divide_round(3)
coin.divide_ceil(3)
coin.divide_floor(3)
coin.divide_bankers(3)
```

### Equality

Value-based: two Coins are equal when they share the same currency and
minor-unit amount.

```ruby
Coin.value(2999, 'USD') == Coin.value(2999, 'USD')  # => true
Coin.value(2999, 'USD') == Coin.value(2999, 'EUR')  # => false

# Works in Sets and as Hash keys
set = Set.new([Coin.value(100, 'USD'), Coin.value(100, 'USD')])
set.size  # => 1
```

---

## Formatting with Presenter

The `present` method accepts a strftime-like pattern:

```ruby
coin = Coin.value(2999, 'USD')  # $29.99

coin.present('%t')           # => "$29.99"          (%t = formatted total)
coin.present('%s%M')         # => "$29.99"          (%s = symbol, %M = major)
coin.present('%M %c')        # => "29.99 USD"
coin.present('%m cents')     # => "2999 cents"      (%m = raw minor units)
```

### Token reference

| Token | Renders                                     |
|-------|---------------------------------------------|
| `%t`  | Full formatted amount (symbol + number)     |
| `%m`  | Raw minor-unit integer                      |
| `%M`  | Major units as decimal string               |
| `%c`  | ISO currency code                           |
| `%s`  | Currency symbol                             |
| `%n`  | Number only (symbol stripped)               |
| `%u`  | Custom units label (pass `units:` option)   |
| `%p`  | Custom per-exact label (pass `per_exact:`)  |
| `~`   | Approximate marker: `≈` or empty string     |
| `%%`  | Literal percent sign                        |

### Presenter options

```ruby
coin.present('~%t', approx: true)             # => "≈$29.99"
coin.present('%M %u', units: 'per kg')        # => "29.99 per kg"
coin.present('%p / unit', per_exact: '0.30')  # => "0.30 / unit"
```

---

## Parsing inputs

`Coin.parse` accepts several input types:

```ruby
# From Money
Coin.parse(Money.new(2999, 'USD'))               # => Coin(2999 USD)

# From float (major units)
Coin.parse(29.99, currency_code: 'USD')          # => Coin(2999 USD)

# From string with embedded symbol
Coin.parse('$29.99')                             # => Coin(2999 USD)

# From string with explicit code
Coin.parse('29.99', currency_code: 'USD')        # => Coin(2999 USD)

# Identity: a Coin is returned as-is
Coin.parse(existing_coin)                        # => existing_coin
```

---

## Per-unit pricing with Allocation

`Allocation` computes per-unit and total pricing from a bulk Coin without
storing any sub-minor-unit values:

```ruby
bulk = product.price            # $100.00 for a pack of 6
alloc = bulk.allocate(per: 6, rounding_policy: :ceil)

alloc.value          # => Coin($16.67)  — per-unit cost
alloc.price(qty: 2)  # => Coin($33.34)  — total for 2 units
alloc.price(qty: 6)  # => Coin($100.00) — reconstitutes the original
```

The Coin is unchanged. Allocation is a non-persisted value object.

---

## Currency input field

Render a bank-style currency input in any form:

```erb
<%= form_with model: @product do |f| %>
  <%= midas_currency_field f, :price,
        currency_code: 'USD',
        label:         'Product Price',
        wrapper_html:  { class: 'mb-4' },
        input_html:    { class: 'rounded border-gray-300 text-right',
                         placeholder: '0.00' } %>

  <%= f.submit 'Save' %>
<% end %>
```

**Typing behaviour:** Digits accumulate from the right.

| Keystrokes | Display  | Hidden (minor) |
|------------|----------|----------------|
| `1`        | `0.01`   | `1`            |
| `12`       | `0.12`   | `12`           |
| `123`      | `1.23`   | `123`          |
| `1234`     | `12.34`  | `1234`         |

The form submits the hidden minor-unit field, which is fed directly to
`set_price(amount: params[:price_minor].to_i, ...)`.

---

## Zero values and nil

```ruby
# Constructing a zero Coin directly
zero = Coin.zero('USD')        # => Coin(0 USD)

# Bankable returns nil if a coin has not been set yet
product.price       # => nil  (before set_price is called)
product.price_amount # => nil
product.price_format # => nil
```

Guard against nil before performing arithmetic:

```ruby
price = product.price || Coin.zero('USD')
```

---

## Working with multiple coins

```ruby
order = Order.create!
order.set_subtotal(amount: 100.00, currency_code: 'USD')
order.set_tax(amount:      8.50,  currency_code: 'USD')
order.set_total(amount:  108.50,  currency_code: 'USD')

# Access all coins on this record
order.midas_coins.count  # => 3
order.midas_coins.map(&:resource_label)
# => ["subtotal", "tax", "total"]

# Arithmetic across coins
order.subtotal + order.tax  # => Coin($108.50)
```

---

## Custom validations

Coins are persisted by `set_*` methods. Validate the parent model:

```ruby
class Product < ApplicationRecord
  include WhittakerTech::Midas::Bankable
  has_coin :price

  validate :price_must_be_positive

  private

  def price_must_be_positive
    return unless price

    errors.add(:price, 'must be positive') unless price.currency_minor > 0
  end
end
```
