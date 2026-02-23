# WhittakerTech::Midas

**Midas** is a Rails engine for elegant, multi-currency monetary value management.

Instead of adding `price_cents` and `price_currency` columns to every model
that needs money, Midas stores all monetary values in a single polymorphic
`Coin` ledger. The `Bankable` concern gives any ActiveRecord model a clean
DSL for declaring and accessing its monetary attributes.

---

## Key capabilities

- **Single canonical ledger** — one `wt_midas_coins` table for every monetary
  value across your entire application
- **Declarative DSL** — `has_coin :price` / `has_coins :subtotal, :tax, :total`
- **Exact arithmetic** — integer minor-unit math, no floating-point errors
- **Flexible input coercion** — accepts Money objects, floats, integers, and strings
- **Token-based formatting** — strftime-like grammar for custom display strings
- **RTL support** — Unicode bidirectional isolation for Arabic and Hebrew UIs
- **Per-unit pricing** — `Allocation` value object for per-unit / bulk pricing
- **Bank-style currency input** — Stimulus controller with automatic decimal handling
- **90%+ test coverage**

---

## Requirements

| Requirement | Version |
|-------------|---------|
| Ruby        | >= 3.4  |
| Rails       | >= 7.1  |
| money gem   | ~> 6.19 |

---

## Quick look

```ruby
class Invoice < ApplicationRecord
  include WhittakerTech::Midas::Bankable

  has_coins :subtotal, :tax, :total
end

invoice = Invoice.create!
invoice.set_subtotal(amount: 100.00, currency_code: 'USD')
invoice.set_tax(amount: 8.50,  currency_code: 'USD')
invoice.set_total(amount: 108.50, currency_code: 'USD')

invoice.subtotal_format   # => "$100.00"
invoice.tax_amount        # => #<Money @fractional=850 @currency="USD">
invoice.total             # => #<WhittakerTech::Midas::Coin ...>
```

---

## Documentation sections

- **[Installation](installation.md)** — add the gem, run migrations, register the Stimulus controller
- **[Usage](usage.md)** — Bankable DSL, Coin arithmetic, Presenter, Allocation
- **[Architecture](architecture.md)** — design decisions, module breakdown, schema
- **[API Reference](api.md)** — full method reference; generated API docs at [`api/WhittakerTech/Midas.md`](api/WhittakerTech/Midas.md)
- **[Examples](examples.md)** — e-commerce products, invoicing, bulk pricing, RTL display

---

## Why Midas?

Monetary code is some of the most fragile code in a Rails application.
Rounding errors, currency mismatches, and schema duplication accumulate
quietly until a financial report or a refund exposes them.

Midas makes the single-ledger approach — standard in accounting software —
the default for Rails. One table, one set of rules, one place to add audit
hooks or exchange rate logic.
