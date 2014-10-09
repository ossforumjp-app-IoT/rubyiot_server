class CreateMonitorRanges < ActiveRecord::Migration
  def change
    create_table :monitor_ranges do |t|
      t.integer :device_property_id
      t.string :min_value
      t.string :max_value
      t.timestamps
    end
  end
end
