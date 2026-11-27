# Peso real em kg de cada item do pedido, anotado na pesagem (R2.6, R2.7; esteira simplificada, passo 5). Fica ao lado
# da quantidade e da unidade do pedido, que não mudam, e vai para o faturamento. Vazio é ainda não pesado.
class AddActualKgToOrderLines < ActiveRecord::Migration[8.1]
  def change
    add_column :order_lines, :actual_kg, :decimal, precision: 10, scale: 3
  end
end
