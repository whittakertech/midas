# WhittakerTech::Midas Changelog

## v0.1.0-preview — Initial Public Release
**December 2025**

This is the first public preview release of **WhittakerTech::Midas**, a Rails engine providing unified monetary management through a single polymorphic Coin ledger. This release includes full documentation, internal test coverage (>90%), and a stable API for early adopters evaluating centralized currency normalization patterns.

### Added
- Core `WhittakerTech::Midas` Rails engine
- Polymorphic `Coin` model for storing all monetary values in a unified ledger
- `Bankable` concern supporting `has_coin` and `has_coins` declarative DSL
- Automatic conversion from integers, floats, decimals, and `Money` objects
- Multi-currency support with configurable exchange rates
- Form helpers including a headless Stimulus-powered bank-style currency field
- Money gem integration with recommended configuration options
- Currency configuration via I18n
- Comprehensive RSpec test suite (>90% coverage)
- Dummy Rails application for manual verification
- Detailed README documentation including architecture diagrams, usage examples, and troubleshooting
- RubyGems metadata, licensing, dependency definitions, and file packaging

### Notes
This is a **preview** release.  
Midas is internally tested and architecturally stable but has not yet been deployed into production within the WhittakerTech ecosystem.  
A stable `v1.0.0` release will follow after real-world validation through integration with Subscribify and Ensemblize.