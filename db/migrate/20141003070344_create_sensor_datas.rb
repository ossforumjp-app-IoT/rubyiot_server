class CreateSensorDatas < ActiveRecord::Migration
  def change
    create_table :sensor_datas do |t|
      t.integer :device_property_id
      t.string :value
      t.timestamp :measured_at
    end
  end
end
