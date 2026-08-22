# frozen_string_literal: true

require 'whittaker_tech/midas'

class CreateMidasLedgerEntries < ActiveRecord::Migration[6.1]
  def change
    create_table WhittakerTech::Midas.table_name('ledger_entries') do |t|
      t.string :currency_code, null: false, limit: 3
      t.datetime :occurred_at, null: false
      t.text :memo
      t.references :source, polymorphic: true, null: true, index: true
      t.datetime :finalized_at

      t.timestamps
    end
  end
end
