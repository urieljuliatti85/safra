class ProductionPlanItem < ApplicationRecord
  acts_as_tenant :company

  belongs_to :production_plan
  belongs_to :product

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :unit, presence: true
end
