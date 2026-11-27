# Dia de execução escolhido pelo Gerente de Produção para cada item (esteira simplificada, passo 4). Vazio é a véspera
# da entrega; a Planilha de Produção e a compra seguem esse dia.
class AddExecutionDateToOrderLines < ActiveRecord::Migration[8.1]
  def change
    add_column :order_lines, :execution_date, :date
  end
end
