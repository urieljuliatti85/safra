class Supplier < ApplicationRecord
  acts_as_tenant :company

  has_many :raw_materials, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :company_id }
end
