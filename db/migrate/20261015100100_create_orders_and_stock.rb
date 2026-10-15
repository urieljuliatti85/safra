class CreateOrdersAndStock < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :company, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.date :week_start, null: false
      t.timestamps
      t.index [ :customer_id, :week_start ], unique: true
    end

    create_table :order_lines do |t|
      t.references :company, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.date :delivery_date, null: false
      t.decimal :quantity, precision: 10, scale: 3, null: false
      t.string :unit, null: false
      t.text :note
      t.timestamps
      t.index [ :company_id, :delivery_date ]
    end

    create_table :stock_counts do |t|
      t.references :company, null: false, foreign_key: true
      t.references :raw_material, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :kg, precision: 10, scale: 3, null: false
      t.timestamps
      t.index [ :raw_material_id, :date ], unique: true
    end

    create_table :purchase_days do |t|
      t.references :company, null: false, foreign_key: true
      t.date :date, null: false
      t.timestamps
      t.index [ :company_id, :date ], unique: true
    end
  end
end
