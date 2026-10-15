class PurchasePlan < ApplicationRecord
  acts_as_tenant :company

  has_many :items, class_name: "PurchasePlanItem", dependent: :destroy

  validates :date, :version, presence: true
  validates :version, uniqueness: { scope: [ :company_id, :date ] }

  def sent?
    sent_at.present?
  end
end
