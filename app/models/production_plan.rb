class ProductionPlan < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  def audit_label = "Produção de #{date.strftime('%d/%m/%Y')} v#{version}"

  has_many :items, class_name: "ProductionPlanItem", dependent: :destroy

  validates :date, :version, presence: true
  validates :version, uniqueness: { scope: [ :company_id, :date ] }

  def sent?
    sent_at.present?
  end
end
