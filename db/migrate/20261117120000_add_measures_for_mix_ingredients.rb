# Medida do ingrediente da mistura e medida do produto quando o pedido não diz (R2.12, R1.20, D30).
# Preenche, em cada empresa, o que a R1.20 e a R2.12 dizem: os ralados e picados das misturas são de 3 mm, e a cenoura
# ralada e os repolhos picados avulsos sem medida também. Só grava onde ainda está vazio, para não sobrescrever o que
# foi editado na tela. A referência dos cortes Ralado e Picado (R1.15) não muda.
class AddMeasuresForMixIngredients < ActiveRecord::Migration[8.1]
  MEASURE = "3 mm".freeze
  MIX_INGREDIENTS = { "yakissoba" => %w[cenoura_ralada repolho_picado], "salada_roxa" => %w[repolho_roxo_picado cenoura_ralada repolho_picado beterraba_ralada] }.freeze
  DEFAULTS = %w[cenoura_ralada repolho_picado repolho_roxo_picado].freeze

  def up
    add_column :product_components, :measure, :string
    add_column :products, :default_measure, :string
    MIX_INGREDIENTS.each do |mix, ingredients|
      execute <<~SQL.squish
        UPDATE product_components SET measure = #{connection.quote(MEASURE)}
        FROM products mix, products ingredient
        WHERE product_components.product_id = mix.id AND product_components.component_id = ingredient.id
          AND mix.code = #{connection.quote(mix)} AND ingredient.code IN (#{ingredients.map { |c| connection.quote(c) }.join(', ')})
          AND product_components.measure IS NULL
      SQL
    end
    execute "UPDATE products SET default_measure = #{connection.quote(MEASURE)} WHERE code IN (#{DEFAULTS.map { |c| connection.quote(c) }.join(', ')})"
  end

  def down
    remove_column :products, :default_measure
    remove_column :product_components, :measure
  end
end
