# Recebimento e conferência (R5.1, R5.2, D47): o recebido de cada compra, por matéria-prima e unidade, na unidade da
# relação (caixas e o avulso em kg ou un), com a divergência em texto.
class CreatePurchaseReceipts < ActiveRecord::Migration[8.1]
  def change
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
