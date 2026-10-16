# Uma aba das planilhas feitas à mão (02 - produção ou 03 - compras CEASA) de um dia, guardada para comparar
# com o que o Safra calcula. Importar de novo o mesmo dia troca as linhas.
class ReferenceSheet < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  KINDS = %w[schedule production purchase].freeze
  KIND_LABELS = { "schedule" => "Programação de produção", "production" => "Planilha de produção", "purchase" => "Compras CEASA" }.freeze

  audited except: %w[imported_by_id]

  def audit_label = "#{KIND_LABELS.fetch(kind, kind)} #{date.strftime('%d/%m/%Y')}"

  belongs_to :imported_by, class_name: "User", optional: true
  has_many :lines, -> { order(:position) }, class_name: "ReferenceSheetLine", dependent: :delete_all, inverse_of: :reference_sheet

  validates :kind, inclusion: { in: KINDS }
  validates :date, presence: true, uniqueness: { scope: %i[company_id kind] }

  def self.weeks = distinct.pluck(:date).map(&:beginning_of_week).uniq.sort.reverse
end
