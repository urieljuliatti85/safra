class CustomerAlias < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  def audit_label = "#{customer&.short_name}: #{name_in_order}"

  belongs_to :customer
  belongs_to :product

  validates :name_in_order, presence: true, uniqueness: { scope: :customer_id }
end
