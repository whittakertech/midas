# Installation

## 1. Add the gem

Add Midas to your `Gemfile`:

```ruby
gem 'whittaker_tech-midas'
```

Then install:

```bash
bundle install
```

---

## 2. Run the install generator

```bash
bin/rails generate whittaker_tech:midas:install
bin/rails db:migrate
```

This copies the engine's migrations to your app and creates the
`wt_midas_coins` table.

Alternatively, run the migration steps manually:

```bash
bin/rails railties:install:migrations FROM=whittaker_tech_midas
bin/rails db:migrate
```

---

## 3. Register the Stimulus controller (optional)

If you use the bank-style currency input field, register the Stimulus
controller in your JavaScript entrypoint:

```javascript
// app/javascript/controllers/index.js
import { application } from "controllers/application"
import { MidasCurrencyController } from "whittaker_tech-midas"

application.register("midas-currency", MidasCurrencyController)
```

---

## 4. Configure the Money gem (recommended)

Create `config/initializers/money.rb`:

```ruby
Money.locale_backend = nil
Money.default_bank   = Money::Bank::VariableExchange.new
Money.rounding_mode  = BigDecimal::ROUND_HALF_EVEN

Money.default_formatting_rules = {
  display_free:       false,
  with_currency:      false,
  no_cents_if_whole:  false,
  format:             '%u%n',
  thousands_separator: ',',
  decimal_mark:        '.'
}
```

---

## 5. Currency configuration (optional)

Midas reads decimal place counts from your I18n files. The engine ships with
defaults for common currencies. Override or extend in your app:

```yaml
# config/locales/midas.en.yml
en:
  midas:
    ui:
      defaults:
        decimal_count: 2
      currencies:
        BTC:
          decimal_count: 8
        CLF:
          decimal_count: 4
```

---

## 6. RTL currency direction (optional)

Configure right-to-left currencies in an initializer:

```ruby
# config/initializers/midas.rb
WhittakerTech::Midas.currency_directions['ILS'] = :rtl
WhittakerTech::Midas.currency_directions['AED'] = :rtl
WhittakerTech::Midas.currency_directions['SAR'] = :rtl
```

---

## 7. PostgreSQL schema namespace (optional)

To place the coins table inside a named PostgreSQL schema:

```ruby
# config/initializers/midas.rb
WhittakerTech::Midas.table_namespace = 'finance'
# => table becomes finance.coins
```

This requires PostgreSQL and the schema must exist before running migrations.

---

## Verifying the installation

```bash
bin/rails runner "puts WhittakerTech::Midas::Coin.count"
# => 0
```

---

## Requirements

| Requirement  | Minimum  |
|--------------|----------|
| Ruby         | 3.4.0    |
| Rails        | 7.1.5.2  |
| money gem    | ~> 6.19  |
| PostgreSQL   | 14+ (recommended); SQLite 3 supported for development |
