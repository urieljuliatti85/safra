class CreateCatalog < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :suppliers do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
      t.index [ :company_id, :name ], unique: true
    end

    create_table :raw_materials do |t|
      t.references :company, null: false, foreign_key: true
      t.references :supplier, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      # nil = ainda não informado: gera alerta, não erro
      t.decimal :multiply_factor, precision: 10, scale: 3
      t.decimal :kg_per_package, precision: 10, scale: 3
      t.decimal :kg_per_peeled_box, precision: 10, scale: 3
      t.string :purchase_package, null: false, default: "kg"
      t.text :note
      t.timestamps
      t.index [ :company_id, :code ], unique: true
    end

    create_table :cuts do |t|
      t.references :company, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :sector, null: false
      t.string :sector_name, null: false
      t.integer :lead_days, null: false, default: 0
      t.timestamps
      t.index [ :company_id, :code ], unique: true
    end

    create_table :products do |t|
      t.references :company, null: false, foreign_key: true
      t.references :raw_material, null: false, foreign_key: true
      t.references :cut, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :product_group, null: false
      t.string :unit, null: false, default: "kg"
      t.timestamps
      t.index [ :company_id, :code ], unique: true
    end

    create_table :production_rules do |t|
      t.references :company, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true, index: { unique: true }
      t.integer :lead_days, null: false
      t.timestamps
    end

    create_table :customers do |t|
      t.references :company, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :short_name, null: false
      t.string :order_source
      t.timestamps
      t.index [ :company_id, :code ], unique: true
    end

    create_table :customer_aliases do |t|
      t.references :company, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :name_in_order, null: false
      t.timestamps
      t.index [ :customer_id, :name_in_order ], unique: true
    end
  end
end
