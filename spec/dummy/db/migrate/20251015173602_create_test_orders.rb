class CreateTestOrders < ActiveRecord::Migration[6.1]
  def change
    create_table :test_orders do |t|
      t.timestamps
    end
  end
end
