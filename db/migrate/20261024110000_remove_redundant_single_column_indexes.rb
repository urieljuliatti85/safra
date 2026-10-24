# Índices de uma coluna que o índice composto da mesma tabela já cobre (a coluna é a primeira do composto).
class RemoveRedundantSingleColumnIndexes < ActiveRecord::Migration[8.1]
  INDEXES = {
    comparison_notes: :company_id, customer_aliases: :customer_id, customers: :company_id, cuts: :company_id,
    order_imports: :company_id, order_lines: :company_id, order_versions: :order_id, orders: :customer_id,
    production_plans: :company_id, products: :company_id, purchase_days: :company_id, purchase_plans: :company_id,
    raw_materials: :company_id, reference_sheet_versions: :reference_sheet_id, reference_sheets: :company_id,
    sheet_aliases: :company_id, sheet_imports: :company_id, stock_counts: :raw_material_id, suppliers: :company_id
  }.freeze

  def change
    INDEXES.each do |table, column|
      remove_index table, column, name: "index_#{table}_on_#{column}"
    end
  end
end
