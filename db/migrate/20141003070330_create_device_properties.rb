class CreateDeviceProperties < ActiveRecord::Migration
  def change
    create_table :device_properties do |t|
      t.integer :gateway_id
      t.integer :device_id
      t.string :name
      t.boolean :sensor
      t.column :class_group_code, :"char(4)"
      t.column :class_code, :"char(4)"
      t.column :property_code, :"char(4)"
      t.timestamps
    end
  end
end
