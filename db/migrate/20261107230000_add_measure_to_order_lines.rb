# Medida pedida pelo cliente para um produto no pedido da semana (R1.14, D12): orienta o preparo, acima da referência do corte.
class AddMeasureToOrderLines < ActiveRecord::Migration[8.1]
  def change
    add_column :order_lines, :measure, :string
  end
end
