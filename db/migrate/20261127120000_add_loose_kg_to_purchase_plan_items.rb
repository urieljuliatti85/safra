# Compra em fração (R3.9, D41): além das caixas inteiras, a versão enviada guarda o resto em kg.
class AddLooseKgToPurchasePlanItems < ActiveRecord::Migration[8.1]
  def change
    add_column :purchase_plan_items, :loose_kg, :decimal, precision: 10, scale: 3, default: 0, null: false
  end
end
