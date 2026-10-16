class Cut < ApplicationRecord
  SECTORS = %w[descasc manual ralpic palito cubinho frutas].freeze

  acts_as_tenant :company
  include Auditable

  has_many :products, dependent: :restrict_with_error

  validates :code, :name, :sector_name, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :sector, inclusion: { in: SECTORS }
  validates :lead_days, numericality: { only_integer: true, in: 0..5 }
end
