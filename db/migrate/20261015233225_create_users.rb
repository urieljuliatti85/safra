class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "office"
      # Senha provisória (criação ou redefinição pelo admin): a pessoa troca no primeiro acesso.
      t.boolean :must_change_password, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
