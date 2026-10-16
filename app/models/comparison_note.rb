# Por que uma diferença entre a planilha e o Safra está explicada ("pedido mudou por telefone na terça").
# Guarda os números do momento: se a planilha ou o Safra mudarem depois, a nota aparece como antiga.
class ComparisonNote < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  def audit_label = "Nota da comparação: #{item} #{date.strftime('%d/%m/%Y')}"

  belongs_to :user, optional: true

  validates :kind, :section, :date, :item, presence: true
  validates :note, presence: true, length: { maximum: 500 }
  validates :item, uniqueness: { scope: %i[company_id kind section date] }

  def self.key_for(row) = [ row.kind.to_s, row.section, row.date, row.code || row.label ]

  def key = [ kind, section, date, item ]

  def current_for?(row) = same?(planilha, row.planilha) && same?(sistema, row.sistema)

  private

  def same?(a, b) = a.nil? ? b.nil? : !b.nil? && (a - b).abs < 0.0005
end
