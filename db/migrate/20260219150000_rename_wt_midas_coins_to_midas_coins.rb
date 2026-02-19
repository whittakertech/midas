# frozen_string_literal: true

class RenameWtMidasCoinsToMidasCoins < ActiveRecord::Migration[8.0]
  def change
    rename_table :wt_midas_coins, :midas_coins
    rename_index :midas_coins,
                 'index_wt_midas_coins_on_resource_and_role',
                 'index_midas_coins_on_resource_and_role'
    rename_index :midas_coins,
                 'index_wt_midas_coins_on_resource',
                 'index_midas_coins_on_resource'
  end
end
