# frozen_string_literal: true

require 'whittaker_tech/midas'

class CreateMidasExchanges < ActiveRecord::Migration[6.1]
  def change
    create_table WhittakerTech::Midas.table_name('exchanges') do |t|
      t.decimal :rate, precision: 24, scale: 12, null: false
      t.string  :source, null: false
      t.datetime :at, null: false

      t.timestamps
    end
  end
end
