# Architecture

Midas replaces the scattered-columns anti-pattern with a single polymorphic
ledger. Every monetary value in your application — regardless of which model
owns it — is stored as a `Coin` record.

---

## The problem Midas solves

The conventional Rails approach is to add per-attribute currency columns to
every model that needs money:

```ruby
# ❌ Schema bloat — each monetary attribute doubles your columns
add_column :products,  :price_cents,        :integer
add_column :products,  :price_currency,     :string
add_column :invoices,  :subtotal_cents,     :integer
add_column :invoices,  :subtotal_currency,  :string
add_column :invoices,  :tax_cents,          :integer
add_column :invoices,  :tax_currency,       :string
# ...repeated across dozens of models
```

Consequences:

- Schema migrations needed for every new monetary attribute
- Rounding and conversion logic duplicated across models
- No single place to enforce currency rules or add audit hooks
- Currency columns crowd schema views and make queries harder to read

---

## The Midas solution: one table

```ruby
# ✅ One table, unlimited monetary attributes on any model
create_table :wt_midas_coins do |t|
  t.references :resource, polymorphic: true, null: false
  t.string  :resource_label,  null: false, limit: 64  # "price", "tax", "deposit"
  t.string  :currency_code,   null: false, limit: 3   # "USD", "EUR", "JPY"
  t.bigint  :currency_minor,  null: false              # integer minor units (cents)
end
```

A unique index on `[resource_id, resource_type, resource_label]` ensures one
Coin per attribute per record.

### Database schema

```
┌──────────────────────────────────────────┐
│            wt_midas_coins                │
├──────────────────────────────────────────┤
│ id             BIGINT        PK          │
│ resource_type  VARCHAR       ─┐          │
│ resource_id    BIGINT        ─┤ Polymorphic
│ resource_label VARCHAR(64)   ─┘          │
│ currency_code  VARCHAR(3)                │
│ currency_minor BIGINT                    │
│ created_at     TIMESTAMP                 │
│ updated_at     TIMESTAMP                 │
└────────────────┬─────────────────────────┘
                 │ has_many :midas_coins, as: :resource
       ┌─────────┴──────────┐
       │   Any model with   │
       │     Bankable       │
       └────────────────────┘
```

---

## Core components

```
WhittakerTech::Midas
│
├── Coin                         ← persisted ActiveRecord model
│   ├── Coin::Arithmetic         ← immutable math (+, -, *, /, %, negate)
│   ├── Coin::Bidi               ← Unicode RTL/LTR isolation
│   ├── Coin::Converter          ← placeholder (not yet implemented)
│   ├── Coin::Presenter          ← strftime-like formatting grammar
│   ├── Coin::Parser             ← input coercion (Money / Numeric / String → Coin)
│   └── Coin::Allocation         ← per-unit pricing value object
│
├── Bankable                     ← concern: has_coin / has_coins DSL
│
└── FormHelper / JS controller   ← bank-style currency input field
```

---

## Coin — the canonical value

`Coin` is an ActiveRecord model, but it behaves like a value object:

- **Identity** = `currency_code` + `currency_minor` (not the database `id`)
- **Immutable by convention** — arithmetic operations return new frozen Coins
- **No sub-minor units** — `currency_minor` is always an integer (cents, not
  fractions of cents)
- **No embedded logic** — formatting, pricing, and conversion live in
  separate modules

### Field semantics

| Field            | Type    | Notes                                              |
|------------------|---------|----------------------------------------------------|
| `resource_type`  | String  | Polymorphic owner class name, e.g. `"Product"`     |
| `resource_id`    | Integer | Polymorphic owner primary key                      |
| `resource_label` | String  | Attribute name, e.g. `"price"`. Unique per resource. |
| `currency_code`  | String  | ISO 4217 3-letter code. Stored uppercase.          |
| `currency_minor` | Integer | Amount in minor units (e.g. cents for USD)         |

---

## Module breakdown

### Arithmetic

```
Coin::Arithmetic
```

All arithmetic is **exact, integer arithmetic** on minor units. No floating
point arithmetic is ever performed on payable values.

| Operation | Policy required? | Notes                              |
|-----------|------------------|------------------------------------|
| `+`       | No               | Currency must match                |
| `-`       | No               | Currency must match                |
| `*`       | No               | Multiplier must be Integer         |
| `%`       | No               | Remainder after integer division   |
| `negate`  | No               | Sign reversal                      |
| `divide`  | **Yes**          | Returns rounded Coin               |

Division is the only operation that can produce a non-integer result when
dividing integer minor units. A **rounding policy** resolves this:

| Policy    | Behaviour                          |
|-----------|------------------------------------|
| `:round`  | Half-up (standard commercial)      |
| `:ceil`   | Always rounds up                   |
| `:floor`  | Always rounds down (truncates)     |
| `:bankers`| Round half-to-even (IEEE 754)      |

Convenience methods are generated for each policy:

```ruby
coin.divide_round(3)   # divide with :round policy
coin.divide_ceil(3)    # divide with :ceil policy
coin.divide_floor(3)
coin.divide_bankers(3)
```

### Presenter

```
Coin::Presenter
```

A strftime-like grammar for rendering Coins as strings. Pure — no mutation,
rounding, or conversion.

| Token | Renders                                |
|-------|----------------------------------------|
| `%t`  | Formatted total (symbol + amount)      |
| `%m`  | Raw minor units integer                |
| `%M`  | Major units as decimal string          |
| `%c`  | ISO currency code                      |
| `%s`  | Currency symbol                        |
| `%n`  | Number only (symbol stripped)          |
| `%u`  | Custom units label (option: `units:`)  |
| `%p`  | Custom per-exact label                 |
| `~`   | Approximate marker (`≈` or empty)      |
| `%%`  | Literal `%`                            |

```ruby
coin = Coin.value(2999, 'USD')
coin.present('%s%M')           # => "$29.99"
coin.present('%t (%c)')        # => "$29.99 (USD)"
coin.present('~%t', approx: true)   # => "≈$29.99"
coin.present('%M %u', units: 'kg')  # => "29.99 kg"
```

### Parser

```
Coin::Parser
```

Coerces input of any supported type into a Coin. The `Coin.parse` class
method delegates here.

| Input type  | Semantic                                        |
|-------------|--------------------------------------------------|
| `Coin`      | Returned unchanged                               |
| `Money`     | `money.cents` + `money.currency.iso_code`        |
| `Numeric`   | Treated as **major** units; requires currency    |
| `String`    | Strips non-numeric chars; requires currency or embedded symbol |

```ruby
Coin.parse(29.99, currency_code: 'USD')    # => Coin(2999 USD)
Coin.parse(Money.new(2999, 'USD'))         # => Coin(2999 USD)
Coin.parse('$29.99')                       # => Coin(2999 USD)
```

### Allocation

```
Coin::Allocation
```

A non-persisted value object for per-unit pricing. Created via
`coin.allocate(per:, rounding_policy:)`.

```ruby
bulk = Coin.value(10_000, 'USD')   # $100.00 for 6 items
alloc = bulk.allocate(per: 6, rounding_policy: :ceil)

alloc.value          # => Coin($16.67) — per-unit cost
alloc.price(qty: 2)  # => Coin($33.34) — total for 2 units
```

### Bidi

```
Coin::Bidi
```

Wraps currency strings in Unicode directional-isolate marks (U+2066 LRI,
U+2067 RLI, U+2069 PDI) to prevent the Unicode Bidirectional Algorithm from
reordering symbol + number sequences in RTL UIs (Arabic, Hebrew, etc.).

Direction defaults to LTR for all currencies. Override per-currency:

```ruby
WhittakerTech::Midas.currency_directions['ILS'] = :rtl
WhittakerTech::Midas.currency_directions['AED'] = :rtl
```

### Converter (reserved)

`Coin::Converter` is a placeholder module. It raises `NotImplementedError`
today. When implemented it will handle exchange rates, historical rates, and
regulatory rounding. Use the Money gem's exchange rate API directly for now.

---

## Bankable concern

`Bankable` is an `ActiveSupport::Concern` that wires the Coin ledger into any
ActiveRecord model.

When you call `has_coin :price`, Bankable:

1. Creates a scoped `has_one :price_coin` association (filters on `resource_label: "price"`)
2. Defines `price`, `price_amount`, `price_format`, and `set_price` instance methods
3. The parent model gets `has_many :midas_coins` for accessing all its coins together

```ruby
class Invoice < ApplicationRecord
  include WhittakerTech::Midas::Bankable

  has_coins :subtotal, :tax, :total
end
```

### Amount coercion in `set_*`

`set_price(amount:, currency_code:)` accepts three input forms:

| Input      | Meaning                                |
|------------|----------------------------------------|
| `Money`    | Minor units taken directly from `.cents` |
| `Integer`  | Treated as minor units                 |
| `Float`/`Numeric` | Treated as major units; scaled by `10 ** decimals_for(iso)` |

---

## FormHelper and Stimulus controller

`midas_currency_field` renders a three-part field group:

```html
<div data-controller="midas-currency"
     data-midas-currency-currency-value="USD"
     data-midas-currency-decimals-value="2">
  <!-- Visible display input (formatted major units) -->
  <input data-midas-currency-target="display" type="text" />
  <!-- Hidden field that holds minor units (submitted with form) -->
  <input data-midas-currency-target="hidden" type="hidden" name="product[price_minor]" />
  <!-- Hidden field for the currency code -->
  <input type="hidden" name="product[price_currency]" value="USD" />
</div>
```

**Bank-style typing:** digits accumulate from the right. Typing `1`, `2`,
`3`, `4` displays `0.01 → 0.12 → 1.23 → 12.34`. Backspace removes the last
digit.

---

## Configuration

### `table_namespace` — PostgreSQL schema namespacing

```ruby
# config/initializers/midas.rb
WhittakerTech::Midas.table_namespace = 'finance'
# => table becomes finance.coins
```

Requires PostgreSQL. Creates the table as `<namespace>.coins` inside the
named schema.

### `currency_directions` — RTL support

```ruby
WhittakerTech::Midas.currency_directions['ILS'] = :rtl
WhittakerTech::Midas.currency_directions['AED'] = :rtl
```

### I18n — decimal places and symbols

```yaml
# config/locales/midas.en.yml
en:
  midas:
    ui:
      defaults:
        decimal_count: 2
      currencies:
        JPY:
          decimal_count: 0
        BTC:
          decimal_count: 8
```

---

## Design principles

### Immutability

Every `Coin` operation that returns a value returns a **new, frozen Coin**.
The receiver is never mutated. This makes Coins safe to pass across service
boundaries and cache without defensive copying.

### Closure

Arithmetic operations are closed over Coin — they always return a Coin, never
a raw integer or float. This prevents accidental loss of currency context.

### No sub-minor units

`currency_minor` is always an integer. There are no fractions of cents stored
anywhere. Division applies a rounding policy before creating the result Coin.

### Separation of concerns

Each module has one job:

- **Arithmetic** — math
- **Presenter** — display strings
- **Parser** — input coercion
- **Allocation** — per-unit pricing
- **Bidi** — RTL/LTR isolation
- **Converter** — (future) exchange rates
