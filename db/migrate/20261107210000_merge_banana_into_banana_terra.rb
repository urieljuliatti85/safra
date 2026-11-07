# A banana dos cortes é a banana-da-terra (R1.18, D17): os produtos e as referências da matéria-prima "banana"
# (Banana para cubinhos) passam para "banana_terra", em cada empresa que tem as duas. A Banana-da-terra fica sem fator
# quando ainda tinha o 1 do seed, como a banana dos cortes (a etapa 3 confirma). A "banana" antiga só é apagada se nada
# mais apontar para ela (histórico de compras ou contagem de estoque na mesma data).
class MergeBananaIntoBananaTerra < ActiveRecord::Migration[8.1]
  def up
    pairs = "FROM raw_materials b JOIN raw_materials t ON t.company_id = b.company_id AND t.code = 'banana_terra' WHERE b.code = 'banana'"
    execute "UPDATE products p SET raw_material_id = t.id #{pairs} AND p.raw_material_id = b.id"
    execute "UPDATE sheet_aliases s SET raw_material_id = t.id #{pairs} AND s.raw_material_id = b.id"
    execute <<~SQL
      UPDATE stock_counts s SET raw_material_id = t.id #{pairs} AND s.raw_material_id = b.id
        AND NOT EXISTS (SELECT 1 FROM stock_counts o WHERE o.raw_material_id = t.id AND o.date = s.date)
    SQL
    execute <<~SQL
      UPDATE raw_materials t SET name = 'Banana-da-terra', multiply_factor = NULL
      WHERE t.code = 'banana_terra' AND t.name = 'Banana da terra' AND t.multiply_factor = 1
        AND EXISTS (SELECT 1 FROM raw_materials b WHERE b.company_id = t.company_id AND b.code = 'banana')
    SQL
    execute <<~SQL
      DELETE FROM raw_materials b
      WHERE b.code = 'banana'
        AND EXISTS (SELECT 1 FROM raw_materials t WHERE t.company_id = b.company_id AND t.code = 'banana_terra')
        AND NOT EXISTS (SELECT 1 FROM products p WHERE p.raw_material_id = b.id)
        AND NOT EXISTS (SELECT 1 FROM sheet_aliases s WHERE s.raw_material_id = b.id)
        AND NOT EXISTS (SELECT 1 FROM stock_counts s WHERE s.raw_material_id = b.id)
        AND NOT EXISTS (SELECT 1 FROM purchase_plan_items i WHERE i.raw_material_id = b.id)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "a junção das bananas não se desfaz sozinha; ver docs/mudancas.md (D17)"
  end
end
