class CreateDeviceProperties < ActiveRecord::Migration
  def change
    create_table :device_properties do |t|
      t.integer :gateway_id
      t.integer :device_id
      t.string :name
      t.column :class_property_code :"char(6)"
      t.timestamps
    end
  end
end
