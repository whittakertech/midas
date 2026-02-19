# frozen_string_literal: true

require 'whittaker_tech/midas'

class RenameResourceLabelToResourceRoleInWtMidasCoins < ActiveRecord::Migration[8.0]
  def change
    rename_column WhittakerTech::Midas.table_name('coins'), :resource_label, :resource_role
    rename_index  WhittakerTech::Midas.table_name('coins'),
                  'index_wt_midas_coins_on_resource_and_label',
                  'index_wt_midas_coins_on_resource_and_role'
  end
end
