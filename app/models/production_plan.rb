class ProductionPlan < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  # Cliente como estava no envio (nome curto e código guardados na abertura do item).
  SentCustomer = Data.define(:code, :short_name)

  def audit_label = "Produção de #{date.strftime('%d/%m/%Y')} v#{version}"

  has_many :items, class_name: "ProductionPlanItem", dependent: :destroy
  belongs_to :sent_by, class_name: "User", optional: true

  validates :date, :version, presence: true
  validates :version, uniqueness: { scope: [ :company_id, :date ] }

  scope :sent, -> { where.not(sent_at: nil) }

  def self.latest_sent(date)
    sent.where(date: date).order(:version).last
  end

  def sent?
    sent_at.present?
  end

  def previous
    @previous ||= ProductionPlan.sent.where(date: date).where(version: ...version).order(:version).last
  end

  def latest?
    ProductionPlan.latest_sent(date) == self
  end

  # O que esta versão mudou em relação à anterior do mesmo dia (vazio na primeira).
  def changes_from_previous
    @changes_from_previous ||= previous ? PlanDiff.production(previous, to_result) : []
  end

  # A versão enviada no formato do cálculo (ProductionPlanner::Result), para a tela e o PDF dos setores
  # mostrarem exatamente o que foi enviado, mesmo que o pedido tenha mudado depois.
  def to_result
    @to_result ||= build_result
  end

  private

  def build_result
    planner_items = items.includes(product: [ :cut, :raw_material ]).map do |item|
      breakdown = Array(item.breakdown).map do |b|
        ProductionPlanner::Breakdown.new(
          customer: SentCustomer.new(code: b["customer_code"], short_name: b["customer"]),
          delivery_date: Date.iso8601(b["delivery_date"]), quantity: BigDecimal(b["quantity"].to_s)
        )
      end
      ProductionPlanner::Item.new(product: item.product, quantity: item.quantity, unit: item.unit, breakdown: breakdown)
    end
    ProductionPlanner.result(date, planner_items)
  end
end
