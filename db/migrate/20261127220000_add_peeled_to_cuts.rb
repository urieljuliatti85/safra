# Relação de descasque e preparo (R3.11, D42): o corte diz se o produto passa pelo descasque. Liga o corte
# "Descascada (unidade)" (laranja descascada) em cada empresa; os outros ficam como estão.
class AddPeeledToCuts < ActiveRecord::Migration[8.1]
  def up
    add_column :cuts, :peeled, :boolean, default: false, null: false
    execute "UPDATE cuts SET peeled = TRUE WHERE code = 'descascada_un'"
  end

  def down
    remove_column :cuts, :peeled
  end
end
