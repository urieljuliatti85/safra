class OrderLine < ApplicationRecord
  UNITS = %w[kg un cx mç].freeze
  # Teto de digitação, bem abaixo do que cabe em decimal(10,3): um número maior é erro de digitação.
  MAX_QUANTITY = 1_000_000

  acts_as_tenant :company
  include Auditable
  audited except: %w[order_id]

  def audit_label = "#{product&.name} · #{order&.customer&.short_name} · entrega #{delivery_date.strftime('%d/%m/%Y')}"

  belongs_to :order
  belongs_to :product

  validates :delivery_date, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0, less_than: MAX_QUANTITY }
  validates :unit, inclusion: { in: UNITS }

  delegate :customer, to: :order
end
