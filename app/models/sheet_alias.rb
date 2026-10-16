# Como as planilhas da empresa escrevem um item ("REPOLHO BR. PICADO", "MAÇÃ CAT.1 – 150"), ligado uma vez a
# um produto, a uma matéria-prima ou, na programação, a um cliente ("CENTRAL"). "Ignorado" tira o item da
# comparação (ex.: algo que o Safra não calcula).
class SheetAlias < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  TARGETS = %w[product raw_material customer].freeze
  TARGET_PROMPTS = { "product" => "Escolha o produto.", "raw_material" => "Escolha a matéria-prima.", "customer" => "Escolha o cliente." }.freeze

  def audit_label = "Planilha: #{label}"

  belongs_to :product, optional: true
  belongs_to :raw_material, optional: true
  belongs_to :customer, optional: true

  validates :target, inclusion: { in: TARGETS }
  validates :label, :name, presence: true
  validates :name, uniqueness: { scope: %i[company_id target] }
  validate :points_somewhere

  before_validation { self.name = ReferenceSheets::Matcher.key(label) if label.present? && name.blank? }

  def record = TARGETS.include?(target) ? public_send(target) : nil

  private

  def points_somewhere
    return if ignored? || record.present?

    errors.add(:base, TARGET_PROMPTS.fetch(target))
  end
end
