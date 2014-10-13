class CreateOperations < ActiveRecord::Migration
  def change
    create_table :operations do |t|
      t.integer :device_property_id
      t.string :value
      t.string :status
      t.timestamps
    end
  end
end
