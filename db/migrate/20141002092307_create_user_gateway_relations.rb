class CreateUserGatewayRelations < ActiveRecord::Migration
  def change
    create_table :user_gateway_relations do |t|
      t.integer :user_id
      t.integer :gateway_id
      t.timestamps
    end
  end
end
