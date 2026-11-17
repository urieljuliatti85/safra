class Cut < ApplicationRecord
  SECTORS = %w[descasc manual ralpic palito cubinho frutas].freeze
  # O setor é a lista de produção em que o corte aparece. O nome do setor é o mesmo para todos os cortes dele.
  SECTOR_NAMES = {
    "descasc" => "Descascados inteiros", "manual" => "Cortes manuais", "ralpic" => "Ralados, picados e rodelas",
    "palito" => "Palitos", "cubinho" => "Cubinhos 10×10 mm", "frutas" => "Frutas descascadas e embaladas"
  }.freeze
  SECTOR_HINTS = {
    "descasc" => "Sai inteiro e descascado. Não entra nos aprontes (caixas para descascar).",
    "manual" => "Cortes feitos à mão: cubos, floretes, lascas, misturas.",
    "ralpic" => "Ralados, picados, rodelas e fatiados.",
    "palito" => "Palitos.",
    "cubinho" => "Cubinhos de 10×10 mm.",
    "frutas" => "Frutas descascadas ou embaladas, vendidas por unidade."
  }.freeze

  acts_as_tenant :company
  include Auditable

  has_many :products, dependent: :restrict_with_error

  validates :code, :name, :sector_name, presence: true
  validates :reference_measure, length: { maximum: 200 }
  validates :reference_measure, presence: { message: "é obrigatória quando a medida é única" }, if: :single_measure?
  validates :name, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :code, uniqueness: { scope: :company_id }
  validates :sector, inclusion: { in: SECTORS }
  validates :lead_days, numericality: { only_integer: true, in: 0..5 }

  before_validation :assign_sector_name, if: -> { sector.present? && (sector_name.blank? || will_save_change_to_sector?) }

  # Medida que orienta o preparo: a do pedido, quando há (R1.14); senão, a de referência. Num corte de medida única
  # (o palito, R2.11), vale sempre a do corte, mesmo com outra medida escrita no pedido; o produto pode ter a sua
  # (Product#fixed_measure, D32).
  def measure_for(requested)
    return reference_measure if single_measure?
    return reference_measure.presence if requested.blank? || Cut.measure_key(requested) == Cut.measure_key(reference_measure)

    requested
  end

  # Chave para comparar medidas: "40x10mm", "40 X 10 mm", "40 × 10" e "40 × 10 mm" são a mesma medida.
  def self.measure_key(measure) = measure.to_s.downcase.tr("x", "×").gsub(/\s+/, "").delete_suffix("mm")

  # Dica no campo de medida do pedido.
  def measure_hint
    return if reference_measure.blank?

    single_measure? ? "#{reference_measure} (medida única)" : reference_measure
  end

  private

  # Mantém um nome só por setor: o que a empresa já usa, senão o padrão.
  def assign_sector_name
    self.sector_name = Cut.where(sector: sector).where.not(id: id).pick(:sector_name) || SECTOR_NAMES[sector]
  end
end
