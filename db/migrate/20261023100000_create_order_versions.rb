# Retrato do pedido de um cliente/semana a cada salvamento que mudou alguma coisa, para ver e restaurar versões.
class CreateOrderVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :order_versions do |t|
      t.references :company, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: { on_delete: :cascade }
      t.integer :version, null: false
      t.string :source, null: false
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :user_name
      t.references :order_import, foreign_key: { on_delete: :nullify }
      t.integer :restored_from_version
      t.jsonb :lines, null: false, default: []
      t.jsonb :changes_list, null: false, default: []
      t.datetime :created_at, null: false
    end
    add_index :order_versions, %i[order_id version], unique: true
  end
end
