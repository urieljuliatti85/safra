class OrderLine < ApplicationRecord
  # Crivo (ou pente, 30 ovos) e dúzia vêm da R1.21 (D9).
  UNITS = %w[kg un cx mç crivo dz].freeze
  # Teto de digitação, bem abaixo do que cabe em decimal(10,3): um número maior é erro de digitação.
  MAX_QUANTITY = 1_000_000
  # Marca de andamento na Programação (R3.4, D35), escolhida pelo Gerente de Produção. A quantidade não se divide.
  SCHEDULE_MARKS = { "produce" => "produzir no dia", "ready" => "já pronto" }.freeze
  SCHEDULE_SYMBOLS = { "produce" => "□", "ready" => "•" }.freeze

  acts_as_tenant :company
  include Auditable
  audited except: %w[order_id]

  def audit_label = "#{product&.name} · #{order&.customer&.short_name} · entrega #{delivery_date.strftime('%d/%m/%Y')}"

  belongs_to :order
  belongs_to :product

  validates :delivery_date, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0, less_than: MAX_QUANTITY }
  validates :unit, inclusion: { in: UNITS }
  validates :schedule_mark, inclusion: { in: SCHEDULE_MARKS.keys }

  delegate :customer, to: :order
end
