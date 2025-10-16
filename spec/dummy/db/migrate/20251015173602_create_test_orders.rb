class CreateTestOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :test_orders do |t|
      t.timestamps
    end
  end
end
