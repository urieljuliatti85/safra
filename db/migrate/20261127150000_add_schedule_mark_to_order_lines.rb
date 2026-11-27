# Marca de andamento de cada item da Programação (R3.4, D35): quadrado (produzir no dia) ou ponto (já pronto).
class AddScheduleMarkToOrderLines < ActiveRecord::Migration[8.1]
  def change
    add_column :order_lines, :schedule_mark, :string, default: "produce", null: false
  end
end
