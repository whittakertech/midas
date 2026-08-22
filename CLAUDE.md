# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Midas (`whittaker_tech-midas`) is a **Rails Engine** for multi-currency monetary value management. It replaces scattered `*_cents` and `*_currency` columns with a single polymorphic `Coin` model backed by a centralized `midas_coins` table. Built on top of the `money` gem (~6.19). Requires Ruby >= 3.2.0 and Rails >= 6.1. Rails 6.1 is supported for legacy consumers and is exercised in CI on Ruby 3.3 only.

As of 0.4.0, Midas also provides **Ledger** — additive double-entry bookkeeping (accounts + balanced postings) alongside Coin/Bankable, for consumers that need a full audit trail rather than a simple stored value. See the Ledger section below.

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

Polymorphic ActiveRecord model storing monetary values. Fields: `resource_type`, `resource_id`, `resource_role`, `currency_code` (ISO 3-letter), `currency_minor` (bigint, minor units like cents). Table: `midas_coins`.

### Coin Modules (app/models/whittaker_tech/midas/coin/)

Each module handles one responsibility:

- **Arithmetic** — Immutable math operations (`+`, `-`, `*`, `/`, `%`, `negate`). All operations return new frozen Coins. Enforces currency matching. Division supports rounding policies (`:round`, `:ceil`, `:floor`, `:bankers`). Value-based equality (`==`, `eql?`, `hash`).
- **Allocation** — Non-persisted value object for per-unit pricing. `#value` returns per-unit amount; `#price(qty:)` returns total.
- **Presenter** — Token-based formatting using strftime-like patterns (`%t`, `%M`, `%m`, `%c`, `%s`, `%n`, `%u`, `%p`, `%~`). Pure function, no mutation.
- **Bidi** — Unicode bidirectional text isolation for RTL currency display.
- **Parser** — Coerces Money, Numeric, String, and Coin inputs into Coin objects.
- **Converter** — `#convert_to`/`#exchange_to` for live currency conversion via a provider-agnostic adapter (default: `Coin::Converter::BankProvider` wrapping `Money.default_bank`). Every conversion writes an immutable `Exchange` audit row (`app/models/whittaker_tech/midas/exchange.rb`) via `has_coins :from, :to`.

### Bankable Concern (`app/models/concerns/whittaker_tech/midas/bankable.rb`)

Mixin for any ActiveRecord model. `has_coin :name` / `has_coins :name1, :name2` generates accessors: `name`, `name_coin`, `name_amount` (Money), `name_format`, `name_in(currency_code)` (conversion, audited via `Exchange`), `set_name(amount:, currency_code:)`, `midas_coins`. Handles input coercion (Money objects, integers as minor units, floats via currency decimal conversion).

### Ledger (`app/models/whittaker_tech/midas/ledger/`) — Phase 1

Additive double-entry bookkeeping, not a replacement for Coin/Bankable — most consumers should keep using `has_coin`/`has_coins` for simple stored values. Ledger is for consumers that need a full audited double-entry trail (billing, subscriptions).

- **`Ledger::Account`** — a chart-of-accounts entry. Either a system account (no `owner`, disambiguated by `slug`, e.g. a per-currency suspense or revenue account) or an owned account (polymorphic `owner`, e.g. a Customer), unique per `(owner, kind, currency)` or `(slug, currency)`. `kind` enum: `asset`, `liability`, `equity`, `revenue`, `expense`, `suspense`. `Account.suspense_for(currency_code)` finds-or-creates the per-currency suspense account (bounded retry against the concurrent-creation race its partial unique index guards). `#balance` returns the raw debit-normal balance, scoped to postings on **finalized** entries only.
- **`Ledger::Entry`** — a balanced transaction. **`Entry.record!(currency_code:, occurred_at:, lines:, source: nil, memo: nil)` is the only sanctioned way to build one** — it constructs the entry, then each posting, then each posting's Coin, sequentially (Coin requires an already-persisted `resource`, same constraint as Exchange/Converter), then calls a private `finalize!` that reloads postings fresh and validates balance/single-currency/positive-amounts/at-least-one-posting in a `:finalize` validation context, stamping `finalized_at` only if valid. Entries and Postings are immutable after creation (`ActiveRecord::ReadOnlyRecord`, same pattern as Exchange). Postings on an already-finalized entry reject any add/destroy/`set_amount` call, raising `Ledger::UnbalancedEntryError` — this is what actually prevents an entry from being unbalanced after the fact, not per-write rechecking (which would false-positive mid-construction, since a single posting is never balanced alone).
- **`Ledger::Posting`** — one debit or credit line. Reuses `Coin` via `Bankable` (`has_coin :amount`) for presentation/conversion parity, but denormalizes `currency_minor` onto the row itself — that's the field balance/report queries actually read (so a future Phase 2 partitioning of this table by `occurred_at` pays off). `direction` enum: `debit`/`credit`.
- **Deferred** (explicitly out of scope for 0.4.0): monthly partitioning of `midas_ledger_postings`, a DB-level balance-invariant backstop, reclassification tooling/aging alerts for suspense balances, multi-currency entries, Subscribify usage-metering ingestion.

### Frontend (`app/javascript/controllers/midas_currency_controller.js`)

Stimulus controller implementing bank-style currency input (digits shift left, e.g., typing `1234` displays `12.34` for USD). Works with `FormHelper#midas_currency_field` which renders a visible display input, hidden minor-units field, and hidden currency code field.

### Rounding Policies (`lib/whittaker_tech/midas.rb`)

Defined in `WhittakerTech::Midas::ROUNDING_POLICIES` hash. Four policies: `:round`, `:ceil`, `:floor`, `:bankers` (half-even).

### Namespacing

All Ruby code lives under `WhittakerTech::Midas`. The engine isolates its namespace. Table naming defaults to `midas_coins` but supports PostgreSQL schema namespacing via `WhittakerTech::Midas.table_namespace`.

## Testing

- RSpec with FactoryBot, shoulda-matchers
- Test database: SQLite via dummy Rails app in `spec/dummy/`
- Coverage target: 90% overall, 80% per file (SimpleCov)
- Factories in `spec/factories/midas_coins.rb`
- Dummy app model `TestOrder` has `has_coins :subtotal, :tax, :total` for integration tests
- Dummy app model `TestCustomer` is a generic polymorphic-owner fixture for `Ledger::Account` specs

## Style Conventions

- Single quotes enforced (RuboCop)
- `FrozenStringLiteralComment` disabled
- `Style/Documentation` disabled
- shoulda-matchers style: `RSpec/ImplicitExpect` enforced as `should`
- Method length max: 15 (concerns excluded)
- ABC size max: 20 (concerns excluded)
- RSpec example length max: 10; multiple expectations max: 3; nested groups max: 4
- Coin operations are **immutable** — always return new frozen Coins, never mutate
