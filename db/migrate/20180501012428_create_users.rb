class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |u|
      u.string :email
      u.string :password_hash
      u.string :token
    end
  end
end
