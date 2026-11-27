# Recebido de uma compra da CEASA (R5.1, D47), na unidade da relação: caixas ou sacos e o avulso (kg, ou un na fruta
# pedida por unidade). Sem conteúdo de embalagem no cadastro, vale só o avulso, que é a quantidade toda.
class PurchaseReceipt < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  def audit_label = "Recebido de #{raw_material&.name} na compra de #{date.strftime('%d/%m/%Y')}"

  belongs_to :raw_material

  validates :date, presence: true
  validates :unit, inclusion: { in: OrderLine::UNITS }
  validates :packages, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 100_000 }, allow_nil: true
  validates :loose, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000 }
  validates :raw_material_id, uniqueness: { scope: %i[company_id date unit] }

  # Aceita vírgula decimal e campo vazio.
  def loose=(value)
    super(value.is_a?(String) ? (value.strip.tr(",", ".").presence || 0) : value)
  end

  def packages=(value)
    super(value.is_a?(String) ? value.strip.presence : value)
  end

  # Quantidade recebida na unidade da matéria-prima (kg ou un): caixas vezes o conteúdo do cadastro, mais o avulso.
  def quantity = self.class.quantity(raw_material, unit, packages, loose)

  def self.quantity(raw_material, unit, packages, loose)
    content = raw_material.package_content(unit)
    content && packages ? packages * content + loose.to_d : loose.to_d + (content ? 0 : packages.to_i)
  end
end
