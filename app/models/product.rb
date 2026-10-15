class Product < ApplicationRecord
  GROUPS = %w[processed raw fruit].freeze
  GROUP_LABELS = { "processed" => "Processados", "fruit" => "Frutas embaladas ou descascadas", "raw" => "In natura" }.freeze
  # Hipótese (a confirmar): in natura é separado e comprado para a véspera da entrega.
  RAW_LEAD_DAYS = 1

  acts_as_tenant :company

  belongs_to :raw_material
  belongs_to :cut, optional: true
  has_one :production_rule, dependent: :destroy
  has_many :customer_aliases, dependent: :destroy
  has_many :order_lines, dependent: :restrict_with_error

  validates :code, :name, :unit, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :product_group, inclusion: { in: GROUPS }
  validates :cut, presence: true, unless: :raw?

  def raw?
    product_group == "raw"
  end

  def sector
    cut&.sector
  end

  # Dias de antecedência: exceção por produto, senão o do corte (in natura: RAW_LEAD_DAYS).
  def lead_days
    production_rule&.lead_days || cut&.lead_days || (raw? ? RAW_LEAD_DAYS : 0)
  end

  # Data em que o item precisa estar pronto para a entrega. Domingo não tem produção: cai para sábado.
  def production_date_for(delivery_date)
    date = delivery_date - lead_days
    date -= 1 while date.sunday?
    date
  end
end
