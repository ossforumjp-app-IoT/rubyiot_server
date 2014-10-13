class CreateSensorAlerts < ActiveRecord::Migration
  def change
    create_table :sensor_alerts do |t|
      t.integer :device_property_id
      t.string :value
      t.string :monitor_min_value
      t.string :monitor_max_value
      t.timestamp :measured_at
    end
  end
end
