# A 01 - PROG. DE PRODUÇÃO traz blocos por cliente e dia de entrega; as notas registram por que uma diferença
# entre a planilha e o Safra está explicada.
class AddScheduleAndNotesToReferenceSheets < ActiveRecord::Migration[8.1]
  def change
    add_column :reference_sheet_lines, :group_label, :string # cliente como está na programação ("CENTRAL")
    add_column :reference_sheet_lines, :delivery_date, :date
    add_reference :sheet_aliases, :customer, foreign_key: true

    create_table :comparison_notes do |t|
      t.references :company, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :section, null: false
      t.date :date, null: false
      t.string :item, null: false # código do produto ou da matéria-prima (ou o nome, se não reconhecido)
      t.text :note, null: false
      t.decimal :planilha, precision: 10, scale: 3 # números quando a nota foi escrita: se mudarem, a nota fica antiga
      t.decimal :sistema, precision: 10, scale: 3
      t.references :user, foreign_key: true
      t.timestamps
    end
    add_index :comparison_notes, %i[company_id kind section date item], unique: true, name: "index_comparison_notes_on_row"
  end
end
