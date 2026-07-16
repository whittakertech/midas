# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [0.4.1] - 2026-07-15

### Fixed

- `Midas::Engine`'s `midas.helpers` initializer registered
  `ActiveSupport.on_load(:action_view) { include WhittakerTech::Midas::FormHelper }`,
  relying on Zeitwerk to resolve the constant. On a Rails 8 host,
  `ActionView::Base` is typically already loaded by the time this
  initializer runs, so `on_load` fires immediately -- before this engine's
  own autoload paths are guaranteed ready -- raising
  `NameError: uninitialized constant WhittakerTech::Midas::FormHelper` on
  boot. Fixed by requiring the helper file directly instead of relying on
  autoload timing. Discovered while mounting Midas into Subscribify (T0).

## [0.4.0] - 2026-07-13

### Added

- Added **Midas::Ledger** — additive double-entry bookkeeping alongside the existing `Coin`/
  `Bankable` system (not a replacement; simple stored values keep using `has_coin`/`has_coins`
  as before):
  - **Ledger::Account** — a chart-of-accounts entry. Either a system account (no owner — e.g. a
    per-currency suspense or revenue account, disambiguated by `slug`) or an owned account
    (polymorphic `owner`, e.g. a Customer), scoped uniquely per `(owner, kind, currency)` or
    `(slug, currency)`. `kind` is one of `asset`, `liability`, `equity`, `revenue`, `expense`, or
    `suspense`. `Account.suspense_for(currency_code)` finds-or-creates the per-currency suspense
    account, retried once against the concurrent-creation race its partial unique index guards
    against. `#balance` returns the raw debit-normal balance.
  - **Ledger::Entry** — a balanced double-entry transaction. `Entry.record!(currency_code:,
    occurred_at:, lines:, source: nil, memo: nil)` is the only sanctioned way to build one —
    it constructs the entry, then each posting, then each posting's Coin (sequentially, since
    Coin requires an already-persisted `resource` — the same constraint `Exchange`/`Converter`
    already has), then finalizes: reloads postings and validates balance, single currency,
    positive amounts, and at-least-one line, stamping `finalized_at` only if valid. Entries (and
    their Postings) are immutable after creation, enforced the same way as `Exchange`.
  - **Ledger::Posting** — one debit or credit line within an Entry. Reuses `Coin` via `Bankable`
    (`has_coin :amount`) for presentation/conversion parity with the rest of the engine, while
    denormalizing `currency_minor` onto the row itself, since that's the field balance/report
    queries actually read. Postings on an already-finalized Entry reject any further add or
    remove, raising `Ledger::UnbalancedEntryError`.
  - Monthly partitioning of `midas_ledger_postings`, a DB-level balance-invariant backstop,
    reclassification tooling/aging alerts for suspense balances, multi-currency entries, and
    Subscribify usage-metering ingestion are deliberately out of scope for this release.

## [0.3.0] - 2026-07-08

### Breaking Changes

- Removed deprecated shims `Coin#resource_label`, `Coin#resource_label=`, and `Coin.for_label` (all
  previously scheduled for removal in `0.3.0` — see `[0.2.0]` Deprecations). Use `resource_role`
  directly and `Coin.for_role`.

### Added

- Implemented live currency conversion: `Coin#convert_to(currency_code, at: nil, using: nil)`
  (aliased `Coin#exchange_to`), provider-agnostic via a new adapter,
  **Coin::Converter::BankProvider**, which wraps `Money.default_bank` by default.
- Added **Exchange**, an immutable audit-log model recording every conversion (`from`/`to` Coins via
  the standard `has_coins :from, :to` Bankable DSL, plus `rate`, `source`, and `at`). Write-only —
  never read back to resolve future conversions.
- Implemented `Coin#format(to:)`, performing a live conversion (and Exchange audit write) before
  formatting.
- Wired up `Bankable`'s `#{name}_in(currency_code)` sugar (e.g. `product.price_in('EUR')`), built on
  `convert_to`.
- Passing a historical `at:` against a provider that doesn't support it (the default `BankProvider`
  has no historical capability) now raises `ArgumentError` instead of silently ignoring it.

### Notes

- `at:` defaults to `nil` (meaning "now") rather than `Time.current` — a signature detail invisible
  to every prior caller, since `convert_to`/`format(to:)` previously always raised
  `NotImplementedError` unconditionally. No existing caller could have depended on the old behavior.
- Regulatory per-jurisdiction rounding and reading `Exchange` history back as a rate cache remain
  out of scope.

---

## [0.2.0] - 2026-02-19

### Breaking Changes

- Renamed table `wt_midas_coins` → `midas_coins` (align with doctrine table prefix convention).
  Run migration `20260219150000_rename_wt_midas_coins_to_midas_coins.rb`.
- Renamed `resource_label` column to `resource_role` in `midas_coins`.
  Run the bundled migration `20260219120000_rename_resource_label_to_resource_role_in_wt_midas_coins.rb`.
- Polymorphic role semantics now delegated to the `Poly::Role` mixin via `poly ~> 1.0`.
- `Coin.for_label` scope renamed to `Coin.for_role` (deprecated alias provided).

### Added

- Introduced **Coin::Allocation**, a non-persisted value object for per-unit pricing and sub-minor calculations.
- Introduced **Coin::Parser**, a dedicated coercion layer for converting Money, Numeric, and String inputs into Coins.
- Added **Coin::Presenter**, a token-based, `strftime`-style formatting system for human-safe monetary rendering.
- Added **Coin::Bidi**, providing Unicode bidirectional isolation for safe LTR/RTL currency display.
- Added configurable **rounding policies** with explicit, test-covered behavior and developer warnings.
- Added dynamic `divide_*` helpers generated from rounding policy definitions.
- `WhittakerTech::Midas::Deprecation` — configurable deprecation manager (`:warn`, `:raise`, `:silence`).
- Deprecated shims: `Coin#resource_label`, `Coin#resource_label=`, `Coin.for_label` — all emit
  deprecation warnings and delegate to their `_role` counterparts.
- `WhittakerTech::Midas.deprecation_behavior` config accessor (default `:warn`).
- `WhittakerTech::Midas.reset_configuration!` utility for test teardown.

### Changed

- Clarified the responsibility boundaries between arithmetic, parsing, allocation, and presentation.
- Enforced immutability across Coin arithmetic and allocation operations.
- Refined table-naming logic to support optional PostgreSQL schema namespaces while preserving SQLite compatibility.

### Deprecations

- `Coin#resource_label` / `Coin#resource_label=` — use `resource_role` directly.
- `Coin.for_label(label)` — use `Coin.for_role(label)`.
- All deprecated APIs will be removed in `0.3.0`.

### Notes

- Currency conversion remains intentionally unimplemented; placeholder logic is excluded from coverage until finalized.
- Test coverage intentionally reflects implemented behavior (99%+), avoiding speculative or misleading tests.

### Deferred

- Placeholder currency conversion logic (explicitly unimplemented).

---

## [0.1.1] – 2025-12-04

### Added

- Added `whittaker_tech:midas:install` Rails generator to install migrations.
- Added namespaced Rake task `midas:install:migrations` for copying engine migrations.
- Added timestamped migration copy logic using sequential UTC offsets.
- Added `rake_tasks` loader to the `WhittakerTech::Midas::Engine` class so Rake tasks automatically load.

### Changed

- Updated README installation instructions to use  
  `bin/rails whittaker_tech:midas:install`  
  instead of `railties:install:migrations`.

### Fixed

- Ensured migrations copy correctly even when multiple files are present, avoiding same-second timestamp collisions.

---

## [0.1.0] – 2025-12-01

### Added

- Initial release of **WhittakerTech Midas**, a Rails Engine providing a unified monetary value system.
- Introduced the **Coin** model for polymorphic monetary storage.
- Added **Bankable** concern for monetizing arbitrary ActiveRecord models.
- Added **FormHelper** (`money_field`, etc.) for view-level currency inputs.
- Added Money gem integration for currency representation and formatting.
- Added isolated Rails engine structure with namespacing under `WhittakerTech::Midas`.
- Added default engine assets, helpers, controller base class, and directory structure.
- Included initial database migrations for monetary storage.
- Added documentation scaffold (`mkdocs.yml`) and repo metadata (.rspec, rubocop config, CI workflows).

---

If you’re reading this, thank you for choosing WhittakerTech Midas.
