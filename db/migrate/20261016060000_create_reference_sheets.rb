# Números das planilhas que a empresa ainda preenche à mão (02 - produção e 03 - compras), lidos de um arquivo
# para comparar com o que o Safra calcula durante o teste em paralelo.
class CreateReferenceSheets < ActiveRecord::Migration[8.1]
  def change
    create_table :reference_sheets do |t|
      t.references :company, null: false, foreign_key: true
      t.string :kind, null: false # production | purchase
      t.date :date, null: false
      t.string :filename
      t.string :tab_name
      t.references :imported_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :reference_sheets, %i[company_id kind date], unique: true

    create_table :reference_sheet_lines do |t|
      t.references :reference_sheet, null: false, foreign_key: { on_delete: :cascade }
      t.string :section, null: false # descascador | aprontes | cortes | compras
      t.string :label, null: false
      t.string :quantity_text
      t.decimal :quantity, precision: 10, scale: 3
      t.string :unit
      t.integer :position, null: false, default: 0
    end

    # Como a planilha escreve cada item ("REPOLHO BR. PICADO"), ligado uma vez a um produto ou matéria-prima.
    create_table :sheet_aliases do |t|
      t.references :company, null: false, foreign_key: true
      t.string :target, null: false # product | raw_material
      t.string :name, null: false   # normalizado
      t.string :label, null: false  # como estava na planilha
      t.references :product, foreign_key: true
      t.references :raw_material, foreign_key: true
      t.boolean :ignored, null: false, default: false
      t.timestamps
    end
    add_index :sheet_aliases, %i[company_id target name], unique: true
  end
end
