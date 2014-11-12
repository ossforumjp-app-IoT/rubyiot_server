class AddDevicePropertiesDeletedAt < ActiveRecord::Migration
  def change
    add_column :device_properties, :deleted_at, :timestamp
  end
end
