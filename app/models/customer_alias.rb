class CustomerAlias < ApplicationRecord
  acts_as_tenant :company

  belongs_to :customer
  belongs_to :product

  validates :name_in_order, presence: true, uniqueness: { scope: :customer_id }
end
