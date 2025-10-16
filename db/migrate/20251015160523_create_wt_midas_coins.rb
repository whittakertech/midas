class CreateWtMidasCoins < ActiveRecord::Migration[8.0]
  def change
    create_table :wt_midas_coins do |t|
      t.references :resource, polymorphic: true, null: false, index: true
      t.string :resource_label, null: false
      t.string :currency_code, null: false, limit: 3
      t.integer :currency_minor, null: false, limit: 8

      t.timestamps

      t.index %i[resource_id resource_type resource_label], name: 'index_wt_midas_coins_on_resource_and_label'
    end
  end
end
