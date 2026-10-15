class Cut < ApplicationRecord
  SECTORS = %w[descasc manual ralpic palito cubinho frutas].freeze

  acts_as_tenant :company

  has_many :products, dependent: :restrict_with_error

  validates :code, :name, :sector_name, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :sector, inclusion: { in: SECTORS }
  validates :lead_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
