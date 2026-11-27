# Fruta pedida por unidade (R3.10, D40): unidades por caixa ou saco na matéria-prima, e o resto em unidades na versão
# enviada da compra. Grava os valores confirmados só onde ainda estão vazios (o que foi editado na tela não muda):
# laranja, 100 unidades por caixa; mamão, caixa de 10 kg; melancia, comprada por unidade. O número de mamões por caixa
# (10 a 12, o que o fornecedor informar) fica para o cadastro.
class AddUnitsPerPackageToRawMaterials < ActiveRecord::Migration[8.1]
  def up
    add_column :raw_materials, :units_per_package, :integer
    add_column :purchase_plan_items, :loose_units, :integer, default: 0, null: false
    execute "UPDATE raw_materials SET units_per_package = 100 WHERE code = 'laranja' AND units_per_package IS NULL"
    execute "UPDATE raw_materials SET kg_per_package = 10 WHERE code = 'mamao' AND kg_per_package IS NULL"
    execute "UPDATE raw_materials SET purchase_package = 'un' WHERE code = 'melancia' AND purchase_package = 'kg'"
  end

  def down
    execute "UPDATE raw_materials SET purchase_package = 'kg' WHERE code = 'melancia' AND purchase_package = 'un'"
    execute "UPDATE raw_materials SET kg_per_package = NULL WHERE code = 'mamao' AND kg_per_package = 10"
    remove_column :purchase_plan_items, :loose_units
    remove_column :raw_materials, :units_per_package
  end
end
