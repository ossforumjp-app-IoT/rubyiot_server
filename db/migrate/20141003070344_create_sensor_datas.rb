class CreateSensorDatas < ActiveRecord::Migration
  def change
    create_table :sensor_datas do |t|
      t.integer :gateway_id
      t.integer :device_id
      t.integer :device_property_id
      t.column :class_property_code :"char(6)"
      t.string :value
      t.column :alert :"char(1)"
      t.timestamp :measured_at
      t.timestamps
    end
  end
end
