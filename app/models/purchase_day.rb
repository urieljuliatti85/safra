class PurchaseDay < ApplicationRecord
  acts_as_tenant :company

  validates :date, presence: true, uniqueness: { scope: :company_id }
end
