class AddUnitToPurchasePlanItems < ActiveRecord::Migration[8.1]
  def change
    # A mesma matéria-prima pode ser pedida em unidades diferentes (ex.: ovos em cx).
    add_column :purchase_plan_items, :unit, :string, null: false, default: "kg"
  end
end
