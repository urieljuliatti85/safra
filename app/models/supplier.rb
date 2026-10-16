class Supplier < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  has_many :raw_materials, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :company_id }
end
