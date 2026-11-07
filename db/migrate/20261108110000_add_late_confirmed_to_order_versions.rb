# Alteração com menos de 48 h da entrega, confirmada pela Hortifruti Modelo (R1.26, D8): a versão guarda a confirmação.
class AddLateConfirmedToOrderVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :order_versions, :late_confirmed, :boolean, null: false, default: false
  end
end
