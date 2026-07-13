class CreateTestCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :test_customers do |t|
      t.timestamps
    end
  end
end
