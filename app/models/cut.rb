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
  validates :name, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :code, uniqueness: { scope: :company_id }
  validates :sector, inclusion: { in: SECTORS }
  validates :lead_days, numericality: { only_integer: true, in: 0..5 }

  before_validation :assign_sector_name, if: -> { sector.present? && (sector_name.blank? || will_save_change_to_sector?) }

  private

  # Mantém um nome só por setor: o que a empresa já usa, senão o padrão.
  def assign_sector_name
    self.sector_name = Cut.where(sector: sector).where.not(id: id).pick(:sector_name) || SECTOR_NAMES[sector]
  end
end
