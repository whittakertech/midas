# WhittakerTech::Midas

WhittakerTech Midas is a lightweight Rails engine that provides money utilities and banking-related building blocks for your Rails applications.

- Money-aware helpers for views and forms
- A model concern for representing and validating bank account details
- Rails-friendly conventions and configuration hooks

Midas is designed to be adopted incrementally: include only what you need.

## Requirements

- Ruby: 3.4+ (tested with 3.4.5)
- Rails: >= 7.1.5.2
- money: ~> 6.19.0

## Installation

Add the gem to your application's Gemfile:

```ruby
# Gemfile
gem 'whittaker_tech-midas', '~> 0.x'
```

Install:

```bash
bundle install
```

If the engine provides migrations (e.g., for bank account–related columns), install them into your host app:

```bash
bin/rails railties:install:migrations FROM=whittaker_tech_midas
bin/rails db:migrate
```

Note: Only install migrations if you intend to persist attributes introduced by the engine. If your app already has suitable columns, you can skip this step.

## Usage

### 1) Bankable model concern

Include the concern in any model that needs to store or validate bank account information.

```ruby
# app/models/vendor_bank_account.rb
class VendorBankAccount < ApplicationRecord
  include WhittakerTech::Midas::Bankable

  # Your model logic here…
end
```

Typical workflow:
- Add columns in a migration for the bank attributes you plan to use (e.g., account holder name, account/routing numbers, IBAN/BIC, country).
- Include the concern in the model that owns those columns.
- Use the provided validations/normalization and any helper methods exposed by the concern.

Example migration (adapt fields to your needs):

```ruby
class AddBankDetailsToVendorBankAccounts < ActiveRecord::Migration[7.1]
  def change
    change_table :vendor_bank_accounts, bulk: true do |t|
      t.string  :bank_name
      t.string  :account_holder_name
      t.string  :account_number, null: false
      t.string  :routing_number
      t.string  :iban
      t.string  :bic
      t.string  :country_code
      t.boolean :primary, default: false, null: false
    end

    add_index :vendor_bank_accounts, :iban
    add_index :vendor_bank_accounts, :routing_number
  end
end
```

Refer to the API docs for `WhittakerTech::Midas::Bankable` for the complete list of attributes, validations, and utility methods.

### 2) Form and view helpers for money/banking

Use the engine’s helpers to render money and bank-related inputs consistently. The helpers leverage the `money` gem for parsing/formatting.

Example (namespaced for clarity; adapt to your conventions):

```erb
<%# app/views/payments/_form.html.erb %>
<%= form_with model: @payment do |f| %>
  <!-- Money input -->
  <%= midas_money_field(f, :amount_cents, currency: 'USD') %>

  <!-- Bank account fields -->
  <%= midas_bank_account_fields(f, scope: :payout_account) %>

  <%= f.submit %>
<% end %>
```

- Pass `currency:` explicitly when appropriate, or configure a global default.
- See `WhittakerTech::Midas::FormHelper` for the full list of helper methods and options.

## Configuration

Define global defaults (e.g., default currency, formatting) in an initializer:

```ruby
# config/initializers/midas.rb
WhittakerTech::Midas.configure do |config|
  # Examples:
  # config.default_currency = 'USD'
  # config.format = :accounting
end
```

Consult the configuration API for available options.

## Testing

This engine uses RSpec.

```bash
bundle exec rspec
```

Optional coverage:

```bash
COVERAGE=true bundle exec rspec
```

## Development

- Ensure compatible Ruby and Rails versions are installed.
- Use the included dummy app under `spec/dummy` for local manual testing.
- Standard Rails engine tasks apply (e.g., installing migrations into the host app).

## Versioning & Release

- Update `lib/whittaker_tech/midas/version.rb`.
- Update `CHANGELOG.md` with notable changes.
- Build and publish to your chosen gem server/registry.

## Security

If you discover a security issue, please email: security@your-org.example (placeholder).

## License

MIT License. See MIT-LICENSE for details.

## Links

- Source: https://github.com/your-org/whittaker_tech-midas
- Changelog: https://github.com/your-org/whittaker_tech-midas/blob/main/CHANGELOG.md
- Issues: https://github.com/your-org/whittaker_tech-midas/issues