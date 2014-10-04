class CreateCotnrollDatas < ActiveRecord::Migration
  def change
    create_table :controll_datas do |t|
      t.integer :gateway_id
      t.integer :device_id
      t.integer :device_property_id
      t.string :value
      t.timestamp :got_at
      t.timestamp :ended_at
      t.string :end_status
      t.timestamps
    end
  end
end
