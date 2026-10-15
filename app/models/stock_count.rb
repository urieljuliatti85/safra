class StockCount < ApplicationRecord
  acts_as_tenant :company

  belongs_to :raw_material

  validates :date, presence: true
  validates :kg, numericality: { greater_than_or_equal_to: 0 }
  validates :date, uniqueness: { scope: :raw_material_id }
end
