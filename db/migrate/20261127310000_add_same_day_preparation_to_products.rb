# Preparo no dia da entrega (R3.7, regras separadas da esteira simplificada): temperos, folhagens e o Yaksoba. Marcado no
# produto, o item do pedido vem com "Executar em" no próprio dia da entrega, em vez da véspera.
class AddSameDayPreparationToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :same_day_preparation, :boolean, default: false, null: false
  end
end
