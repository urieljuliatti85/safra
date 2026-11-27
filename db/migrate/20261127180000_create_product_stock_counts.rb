# Saldo de produto pronto (R3.8, D39): contagem por produto e dia, na unidade do produto.
class CreateProductStockCounts < ActiveRecord::Migration[8.1]
  def change
    create_table :product_stock_counts do |t|
      t.references :company, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true, index: false
      t.date :date, null: false
      t.decimal :quantity, precision: 10, scale: 3, null: false
      t.timestamps
    end
    add_index :product_stock_counts, %i[product_id date], unique: true
  end
end
