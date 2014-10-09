class CreateSensorHourlyDatas < ActiveRecord::Migration
  def change
    create_table :sensor_hourly_datas do |t|
      t.integer :device_property_id
      t.string :value
      t.string :min_3rd_value
      t.string :max_3rd_value
      t.timestamp :measured_at
    end
  end
end
