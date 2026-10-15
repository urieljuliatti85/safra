class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :production_plans do |t|
      t.references :company, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :version, null: false, default: 1
      t.datetime :sent_at
      t.timestamps
      t.index [ :company_id, :date, :version ], unique: true
    end

    create_table :production_plan_items do |t|
      t.references :company, null: false, foreign_key: true
      t.references :production_plan, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 3, null: false
      t.string :unit, null: false
      t.jsonb :breakdown, null: false, default: []
      t.timestamps
    end

    create_table :purchase_plans do |t|
      t.references :company, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :version, null: false, default: 1
      t.datetime :sent_at
      t.timestamps
      t.index [ :company_id, :date, :version ], unique: true
    end

    create_table :purchase_plan_items do |t|
      t.references :company, null: false, foreign_key: true
      t.references :purchase_plan, null: false, foreign_key: true
      t.references :raw_material, null: false, foreign_key: true
      t.decimal :kg, precision: 10, scale: 3, null: false
      t.integer :packages
      t.jsonb :breakdown, null: false, default: []
      t.timestamps
    end
  end
end
