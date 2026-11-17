class Product < ApplicationRecord
  GROUPS = %w[processed raw fruit].freeze
  GROUP_LABELS = { "processed" => "Processados", "fruit" => "Frutas embaladas ou descascadas", "raw" => "In natura" }.freeze

  acts_as_tenant :company
  include Auditable

  belongs_to :raw_material
  belongs_to :cut, optional: true
  has_one :production_rule, dependent: :destroy
  has_many :customer_aliases, dependent: :destroy
  has_many :sheet_aliases, dependent: :destroy
  has_many :order_lines, dependent: :restrict_with_error
  # Ingredientes, quando o produto é uma mistura (D18).
  has_many :components, -> { order(percentage: :desc) }, class_name: "ProductComponent", dependent: :destroy, inverse_of: :product
  # Ingrediente de alguma mistura não pode ser apagado sem tirar da mistura antes.
  has_many :used_in_mixes, class_name: "ProductComponent", foreign_key: :component_id, dependent: :restrict_with_error, inverse_of: :component

  validates :code, :name, :unit, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :product_group, inclusion: { in: GROUPS }
  validates :cut, presence: true, unless: :raw?
  validates :cut, absence: true, if: :raw?
  validates :unit, inclusion: { in: OrderLine::UNITS }
  validates :default_measure, length: { maximum: 200 }
  normalizes :default_measure, with: ->(value) { value.strip.presence }

  def raw?
    product_group == "raw"
  end

  def sector
    cut&.sector
  end

  # Medida que orienta o preparo (R1.14, R2.11, R2.12; D30, D32): a do pedido; sem ela, a do produto ("medida quando o pedido
  # não diz", como os 3 mm da cenoura ralada); sem as duas, a de referência do corte. Corte de medida única fica acima de tudo.
  def measure_for(requested) = fixed_measure || cut&.measure_for(requested.presence || default_measure)

  # Num corte de medida única, a medida que sai sempre, mesmo com outra no pedido: a do produto, se houver; senão, a do
  # corte (R2.11, D32: a vagem em palitos é 40 × 10 mm; os outros palitos, 10 × 10 × 60 mm, a do corte).
  def fixed_measure
    return unless cut&.single_measure?

    default_measure.presence || cut.reference_measure
  end

  # Dica no campo de medida do pedido.
  def measure_hint
    return "#{fixed_measure} (medida única)" if fixed_measure
    return cut&.measure_hint if cut.nil? || default_measure.blank?

    default_measure
  end

  # Dias de antecedência: exceção por produto, senão o do corte; in natura segue a regra da empresa.
  def lead_days
    production_rule&.lead_days || cut&.lead_days || (raw? ? (ActsAsTenant.current_tenant&.raw_lead_days || 1) : 0)
  end

  # Data em que o item precisa estar pronto para a entrega. Domingo não tem produção: cai para sábado.
  def production_date_for(delivery_date)
    date = delivery_date - lead_days
    date -= 1 while date.sunday?
    date
  end
end
