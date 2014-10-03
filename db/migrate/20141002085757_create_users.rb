class CreateUsers < ActiveRecord::Migration
	def change
		create_table :users do |t|
			t.string :login_name
			t.string :password_hash
      t.string :email
      t.string :nickname
      t.timestamps
    end
	end
end
