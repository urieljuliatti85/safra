# Quando o pedido chegou do cliente (R1.4, D7): o prazo é comparado com a chegada, não com o lançamento.
class AddReceivedAtToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :received_at, :datetime
  end
end
