class CreateMonitorRanges < ActiveRecord::Migration
  def change
    create_table :sensor_datas do |t|
      t.integer :gateway_id
      t.integer :device_id
      t.integer :device_property_id
      t.column :class_property_code :"char(6)"
      t.string :min_value
      t.string :max_value
      t.timestamps
    end
  end
end
