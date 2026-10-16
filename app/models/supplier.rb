class Supplier < ApplicationRecord
  acts_as_tenant :company

  has_many :raw_materials, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :company_id }
end
