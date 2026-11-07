# Cliente com pedido mensal (R1.5) e número da AF em cada linha do pedido (R1.27, D4). A Nutrir já existente é marcada
# como mensal.
class AddMonthlyOrdersAndAfNumber < ActiveRecord::Migration[8.1]
  def up
    add_column :customers, :monthly_orders, :boolean, null: false, default: false
    add_column :order_lines, :af_number, :string
    add_index :order_lines, %i[order_id af_number]
    execute "UPDATE customers SET monthly_orders = TRUE WHERE code = 'nutrir'"
  end

  def down
    remove_index :order_lines, %i[order_id af_number]
    remove_column :order_lines, :af_number
    remove_column :customers, :monthly_orders
  end
end
