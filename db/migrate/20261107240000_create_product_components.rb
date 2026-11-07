# Composição das misturas (R1.19, R1.20; D18): cada ingrediente é um produto (matéria-prima + corte) com o percentual
# sobre o peso. Também troca o nome "Mistura yakissoba" por "Yaksoba" onde ainda está como o seed deixou.
class CreateProductComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :product_components do |t|
      t.references :company, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :component, null: false, foreign_key: { to_table: :products }
      t.decimal :percentage, precision: 7, scale: 4, null: false
      t.timestamps
    end
    add_index :product_components, %i[product_id component_id], unique: true

    reversible do |dir|
      dir.up { execute "UPDATE products SET name = 'Yaksoba' WHERE code = 'yakissoba' AND name = 'Mistura yakissoba'" }
      dir.down { execute "UPDATE products SET name = 'Mistura yakissoba' WHERE code = 'yakissoba' AND name = 'Yaksoba'" }
    end
  end
end
