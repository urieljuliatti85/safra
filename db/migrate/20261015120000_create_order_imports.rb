class CreateOrderImports < ActiveRecord::Migration[8.1]
  def change
    create_table :order_imports do |t|
      t.references :company, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :filename, null: false
      t.date :week_start, null: false
      # Linhas lidas do arquivo: [{ line, name, unit, quantities: { "2026-10-13" => "7" }, warnings: [] }]
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.datetime :applied_at
      t.timestamps
      t.index [ :company_id, :created_at ]
    end
  end
end
