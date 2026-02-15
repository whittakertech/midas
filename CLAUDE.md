# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Midas (`whittaker_tech-midas`) is a **Rails Engine** for multi-currency monetary value management. It replaces scattered `*_cents` and `*_currency` columns with a single polymorphic `Coin` model backed by a centralized `wt_midas_coins` table. Built on top of the `money` gem (~6.19). Requires Ruby >= 3.4.0 and Rails >= 7.1.5.2.

## Commands

```bash
# Install dependencies
bundle install

# Run full test suite
bundle exec rspec

# Run a single test file
bundle exec rspec spec/models/whittaker_tech/midas/coin_spec.rb

# Run a specific example by line number
bundle exec rspec spec/models/whittaker_tech/midas/coin_spec.rb:42

# Run tests with coverage report
COVERAGE=true bundle exec rspec

# Lint
bundle exec rubocop

# Lint with auto-correct
bundle exec rubocop -A

# Setup test database (from project root)
cd spec/dummy && bin/rails db:create db:migrate && cd ../..
```

## Architecture

### Core Model: `Coin` (`app/models/whittaker_tech/midas/coin.rb`)

Polymorphic ActiveRecord model storing monetary values. Fields: `resource_type`, `resource_id`, `resource_label`, `currency_code` (ISO 3-letter), `currency_minor` (bigint, minor units like cents). Table: `wt_midas_coins`.

### Coin Modules (app/models/whittaker_tech/midas/coin/)

Each module handles one responsibility:

- **Arithmetic** — Immutable math operations (`+`, `-`, `*`, `/`, `%`, `negate`). All operations return new frozen Coins. Enforces currency matching. Division supports rounding policies (`:round`, `:ceil`, `:floor`, `:bankers`). Value-based equality (`==`, `eql?`, `hash`).
- **Allocation** — Non-persisted value object for per-unit pricing. `#value` returns per-unit amount; `#price(qty:)` returns total.
- **Presenter** — Token-based formatting using strftime-like patterns (`%t`, `%M`, `%m`, `%c`, `%s`, `%n`, `%u`, `%p`, `~`). Pure function, no mutation.
- **Bidi** — Unicode bidirectional text isolation for RTL currency display.
- **Parser** — Coerces Money, Numeric, String, and Coin inputs into Coin objects.
- **Converter** — Placeholder module, intentionally unimplemented.

### Bankable Concern (`app/models/concerns/bankable.rb`)

Mixin for any ActiveRecord model. `has_coin :name` / `has_coins :name1, :name2` generates accessors: `name`, `name_coin`, `name_amount` (Money), `name_format`, `set_name(amount:, currency_code:)`, `midas_coins`. Handles input coercion (Money objects, integers as minor units, floats via currency decimal conversion).

### Frontend (`app/javascript/controllers/midas_currency_controller.js`)

Stimulus controller implementing bank-style currency input (digits shift left, e.g., typing `1234` displays `12.34` for USD). Works with `FormHelper#midas_currency_field` which renders a visible display input, hidden minor-units field, and hidden currency code field.

### Rounding Policies (`lib/whittaker_tech/midas.rb`)

Defined in `WhittakerTech::Midas::ROUNDING_POLICIES` hash. Four policies: `:round`, `:ceil`, `:floor`, `:bankers` (half-even).

### Namespacing

All Ruby code lives under `WhittakerTech::Midas`. The engine isolates its namespace. Table naming defaults to `wt_midas_coins` but supports PostgreSQL schema namespacing via `WhittakerTech::Midas.table_namespace`.

## Testing

- RSpec with FactoryBot, shoulda-matchers
- Test database: SQLite via dummy Rails app in `spec/dummy/`
- Coverage target: 90% overall, 80% per file (SimpleCov)
- Factories in `spec/factories/wt_midas_coins.rb`
- Dummy app model `TestOrder` has `has_coins :subtotal, :tax, :total` for integration tests

## Style Conventions

- Single quotes enforced (RuboCop)
- `FrozenStringLiteralComment` disabled
- `Style/Documentation` disabled
- shoulda-matchers style: `RSpec/ImplicitExpect` enforced as `should`
- Method length max: 15 (concerns excluded)
- ABC size max: 20 (concerns excluded)
- RSpec example length max: 10; multiple expectations max: 3; nested groups max: 4
- Coin operations are **immutable** — always return new frozen Coins, never mutate
