class PurchasePlanItem < ApplicationRecord
  acts_as_tenant :company

  belongs_to :purchase_plan
  belongs_to :raw_material

  validates :kg, numericality: { greater_than_or_equal_to: 0 }

  # Mesma leitura de uma PurchasePlanner::Need, para o texto da relação (Formatting.need_text).
  def net_kg = kg
end
