# frozen_string_literal: true

require 'whittaker_tech/midas'

class CreateMidasLedgerPostings < ActiveRecord::Migration[6.1]
  def change
    create_table WhittakerTech::Midas.table_name('ledger_postings') do |t|
      t.references(
        :entry, null: false, index: true,
                foreign_key: { to_table: WhittakerTech::Midas.table_name('ledger_entries') }
      )
      t.references(
        :account, null: false, index: true,
                  foreign_key: { to_table: WhittakerTech::Midas.table_name('ledger_accounts') }
      )
      t.string :direction, null: false
      # Nullable: populated by #set_amount after the row is created (Coin
      # requires a persisted `resource`, so a Posting always exists briefly
      # without an amount). Entry#finalize! rejects any posting still nil.
      t.bigint :currency_minor
      t.datetime :occurred_at, null: false

      t.timestamps

      t.index %i[account_id occurred_at], name: 'index_ledger_postings_on_account_and_occurred_at'
    end

    add_check_constraint(
      WhittakerTech::Midas.table_name('ledger_postings'),
      "direction IN ('debit', 'credit')",
      name: 'ledger_postings_direction_check'
    )
  end
end
