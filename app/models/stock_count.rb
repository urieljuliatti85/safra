class StockCount < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  def audit_label = "Contagem de #{raw_material&.name} em #{date.strftime('%d/%m/%Y')}"

  belongs_to :raw_material

  validates :date, presence: true
  validates :kg, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000 }

  # Aceita vírgula decimal ("12,5"). Troca na atribuição porque a validação de número lê o texto original.
  def kg=(value)
    super(value.is_a?(String) ? value.strip.tr(",", ".") : value)
  end
  validates :date, uniqueness: { scope: :raw_material_id }
end
