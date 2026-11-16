# Medida de cada item da produção enviada (R2.4, D24): a produção passa a separar o mesmo produto por medida.
# As versões já enviadas ficam com a medida vazia: foram calculadas uma linha por produto, na medida de referência,
# e a comparação com o cálculo novo trata medida vazia e medida de referência como a mesma (PlanDiff).
class AddMeasureToProductionPlanItems < ActiveRecord::Migration[8.1]
  def change
    add_column :production_plan_items, :measure, :string
  end
end
