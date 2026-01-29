# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

---

## Unreleased
### Added
- Introduced **Coin::Allocation**, a non-persisted value object for per-unit pricing and sub-minor calculations.
- Introduced **Coin::Parser**, a dedicated coercion layer for converting Money, Numeric, and String inputs into Coins.
- Added **Coin::Presenter**, a token-based, `strftime`-style formatting system for human-safe monetary rendering.
- Added **Coin::Bidi**, providing Unicode bidirectional isolation for safe LTR/RTL currency display.
- Added configurable **rounding policies** with explicit, test-covered behavior and developer warnings.
- Added dynamic `divide_*` helpers generated from rounding policy definitions.

### Changed
- Clarified the responsibility boundaries between arithmetic, parsing, allocation, and presentation.
- Enforced immutability across Coin arithmetic and allocation operations.
- Refined table-naming logic to support optional PostgreSQL schema namespaces while preserving SQLite compatibility.

### Notes
- Currency conversion remains intentionally unimplemented; placeholder logic is excluded from coverage until finalized.
- Test coverage intentionally reflects implemented behavior (99%+), avoiding speculative or misleading tests.


### Deferred
- Placeholder currency conversion logic (explicitly unimplemented).

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
