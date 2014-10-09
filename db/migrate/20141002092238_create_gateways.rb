class CreateGateways < ActiveRecord::Migration
  def change
    create_table :gateways do |t|
      t.string :hardware_uid
      t.string :name
      t.timestamps
    end
  end
end
