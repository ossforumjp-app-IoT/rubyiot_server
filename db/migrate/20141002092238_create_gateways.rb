class CreateGateways < ActiveRecord::Migration
  def change
    create_table :gateways do |t|
      t.string :identification_number
      t.string :name
      t.timestamps
    end
  end
end
