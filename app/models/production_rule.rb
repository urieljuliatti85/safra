class ProductionRule < ApplicationRecord
  acts_as_tenant :company

  belongs_to :product

  validates :lead_days, numericality: { only_integer: true, in: 0..5 }
end
