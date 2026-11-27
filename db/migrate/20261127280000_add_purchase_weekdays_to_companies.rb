# Dias de compra na CEASA por dia da semana (esteira simplificada, passo 3): segunda e quinta por padrão. Substitui o
# cadastro data por data (purchase_days), que fica guardado sem uso.
class AddPurchaseWeekdaysToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :purchase_weekdays, :integer, array: true, null: false, default: [ 1, 4 ]
  end
end
