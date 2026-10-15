class ProductionRule < ApplicationRecord
  acts_as_tenant :company

  belongs_to :product

  validates :lead_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
