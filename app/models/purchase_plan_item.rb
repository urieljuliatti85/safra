class PurchasePlanItem < ApplicationRecord
  acts_as_tenant :company

  belongs_to :purchase_plan
  belongs_to :raw_material

  validates :kg, numericality: { greater_than_or_equal_to: 0 }

  # Mesma leitura de uma PurchasePlanner::Need, para o texto da relação (Formatting.need_text).
  def net_kg = kg

  # Quantidade enviada na unidade da matéria-prima (kg ou un), para conferir com o recebido (D47).
  def quantity = packages ? PurchaseReceipt.quantity(raw_material, unit, packages, loose_kg + loose_units) : kg
end
