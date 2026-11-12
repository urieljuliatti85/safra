# Unidade de destino que o cliente de pedido mensal atende nas AFs (R1.2, D1). Antes ficava fixa no código; agora é
# do cadastro do cliente. Preenche com a unidade das AFs já importadas de cada cliente, quando há uma só.
class AddAfUnitCodeToCustomers < ActiveRecord::Migration[8.1]
  def up
    add_column :customers, :af_unit_code, :string

    rows = select_rows(<<~SQL)
      SELECT customer_id, af ->> 'unit_code'
      FROM order_imports, jsonb_array_elements(payload -> 'afs') AS af
      WHERE kind = 'af' AND af ->> 'unit_code' IS NOT NULL
    SQL
    rows.group_by(&:first).each do |customer_id, pairs|
      codes = pairs.map(&:last).uniq
      next unless codes.one?

      execute "UPDATE customers SET af_unit_code = #{connection.quote(codes.first)} WHERE id = #{customer_id.to_i}"
    end
  end

  def down
    remove_column :customers, :af_unit_code
  end
end
