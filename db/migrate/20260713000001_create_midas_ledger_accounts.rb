# frozen_string_literal: true

require 'whittaker_tech/midas'

class CreateMidasLedgerAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table WhittakerTech::Midas.table_name('ledger_accounts') do |t|
      t.references :owner, polymorphic: true, null: true, index: true
      t.string :kind, null: false
      t.string :slug, limit: 64
      t.string :currency_code, null: false, limit: 3
      t.string :name

      t.timestamps

      t.index %i[owner_type owner_id kind currency_code],
              unique: true,
              name: 'index_ledger_accounts_on_owner_kind_currency'

      t.index %i[slug currency_code],
              unique: true,
              where: 'owner_id IS NULL',
              name: 'index_ledger_accounts_on_slug_currency_when_system'
    end
  end
end
