class CreateTestCustomers < ActiveRecord::Migration[6.1]
  def change
    create_table :test_customers do |t|
      t.timestamps
    end
  end
end
