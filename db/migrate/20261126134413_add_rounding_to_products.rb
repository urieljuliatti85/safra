class AddRoundingToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :rounding, :integer, default: 0, null: false
    # 0 = caixa inteira (round up to whole box), 1 = fração (permite fração de caixa)
  end
end
