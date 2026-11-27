# O Gerente de Produção não quer o recebimento da compra no sistema (4.13): sai a tabela criada para o D47.
class DropPurchaseReceipts < ActiveRecord::Migration[8.1]
  def up
    drop_table :purchase_receipts
  end

  def down
    create_table :purchase_receipts do |t|
      t.references :company, null: false, foreign_key: true
      t.references :raw_material, null: false, foreign_key: true
      t.date :date, null: false
      t.string :unit, null: false, default: "kg"
      t.integer :packages
      t.decimal :loose, precision: 10, scale: 3, null: false, default: 0
      t.text :note
      t.timestamps
    end
    add_index :purchase_receipts, %i[company_id date raw_material_id unit], unique: true, name: "index_purchase_receipts_unique"
  end
end
