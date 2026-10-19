# Aparelhos que recebem aviso (push) quando sai versão nova da produção, com os setores que cada pessoa acompanha.
class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.string :sectors, array: true, null: false, default: []
      t.timestamps
    end
    add_index :push_subscriptions, :endpoint, unique: true
  end
end
