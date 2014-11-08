class AddSensorDataIndexes < ActiveRecord::Migration
  def change
    add_index :sensor_datas, [ :measured_at, :device_property_id ], name: 'index_sensor_datas_on_measured_at'
    add_index :sensor_hourly_datas, [ :measured_at, :device_property_id ], name: 'index_sensor_hourly_datas_on_mesured_at'
  end
end
