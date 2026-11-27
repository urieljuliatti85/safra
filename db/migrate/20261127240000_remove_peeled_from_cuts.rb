# A caixa "Passa pelo descasque" no corte virava um cadastro de operações, e as operações vêm das ordens de serviço do
# Gerente de Produção (R3.11, D34). A laranja descascada entra no descasque pelo texto da esteira ("Laranja descascada
# inclui descasque"), sem campo no corte.
class RemovePeeledFromCuts < ActiveRecord::Migration[8.1]
  def up
    remove_column :cuts, :peeled
  end

  def down
    add_column :cuts, :peeled, :boolean, default: false, null: false
    execute "UPDATE cuts SET peeled = TRUE WHERE code = 'descascada_un'"
  end
end
