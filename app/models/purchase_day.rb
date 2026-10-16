class PurchaseDay < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  def audit_label = "Compra #{date.strftime('%d/%m/%Y')}"

  validates :date, presence: true, uniqueness: { scope: :company_id }
end
