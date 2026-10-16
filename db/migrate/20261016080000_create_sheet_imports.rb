# Histórico das planilhas importadas: cada envio vira um SheetImport e cada aba lida vira uma versão do dia, com as
# linhas como estavam. Importar o mesmo dia de novo cria a versão seguinte sem apagar a anterior.
class CreateSheetImports < ActiveRecord::Migration[8.1]
  def up
    create_table :sheet_imports do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.date :week_start, null: false
      t.jsonb :filenames, null: false, default: []
      t.timestamps
    end
    add_index :sheet_imports, %i[company_id week_start]

    create_table :reference_sheet_versions do |t|
      t.references :company, null: false, foreign_key: true
      t.references :reference_sheet, null: false, foreign_key: { on_delete: :cascade }
      t.references :sheet_import, foreign_key: { on_delete: :nullify }
      t.integer :version, null: false
      t.string :filename
      t.string :tab_name
      t.references :imported_by, foreign_key: { to_table: :users }
      t.jsonb :lines, null: false, default: []
      t.datetime :created_at, null: false
    end
    add_index :reference_sheet_versions, %i[reference_sheet_id version], unique: true

    backfill
  end

  def down
    drop_table :reference_sheet_versions
    drop_table :sheet_imports
  end

  private

  # O que já estava importado vira a versão 1 de cada dia, agrupado num envio por semana e por quem importou.
  def backfill
    sheets = connection.select_all(<<~SQL).to_a
      SELECT id, company_id, kind, date, filename, tab_name, imported_by_id, updated_at FROM reference_sheets ORDER BY id
    SQL
    sheets.group_by { |s| [ s["company_id"], Date.parse(s["date"].to_s).beginning_of_week, s["imported_by_id"] ] }.each do |(company_id, week, user_id), group|
      at = group.map { |s| s["updated_at"] }.max
      import_id = insert_returning(<<~SQL, [ company_id, user_id, week, group.filter_map { |s| s["filename"] }.uniq.to_json, at, at ])
        INSERT INTO sheet_imports (company_id, user_id, week_start, filenames, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id
      SQL
      group.each do |sheet|
        lines = connection.select_all(<<~SQL, "lines", [ sheet["id"] ]).map { |line| line.merge("quantity" => line["quantity"]&.to_s) }
          SELECT section, label, quantity_text, quantity, unit, group_label, delivery_date FROM reference_sheet_lines
          WHERE reference_sheet_id = $1 ORDER BY position, id
        SQL
        connection.exec_query(<<~SQL, "version", [ sheet["company_id"], sheet["id"], import_id, sheet["filename"], sheet["tab_name"], sheet["imported_by_id"], lines.to_json, sheet["updated_at"] ])
          INSERT INTO reference_sheet_versions (company_id, reference_sheet_id, sheet_import_id, version, filename, tab_name, imported_by_id, lines, created_at)
          VALUES ($1, $2, $3, 1, $4, $5, $6, $7, $8)
        SQL
      end
    end
  end

  def insert_returning(sql, binds) = connection.exec_query(sql, "import", binds).rows.first.first
end
