class CreateDevices < ActiveRecord::Migration
  def change
    create_table :devices do |t|
      t.integer :gateway_id
      t.string :identification_number
      t.string :name
      t.column :class_code :"char(4)"
      t.timestamps
    end
  end
end
