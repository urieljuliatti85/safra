# Um envio de planilhas pela tela de importação: quem enviou, quando, quais arquivos e as abas (versões) que foram lidas.
class SheetImport < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  def audit_label = "Planilhas da semana de #{week_start.strftime('%d/%m/%Y')}: #{filenames.join(', ')}".truncate(200)

  belongs_to :user, optional: true
  has_many :versions, class_name: "ReferenceSheetVersion", dependent: :nullify, inverse_of: :sheet_import

  validates :week_start, presence: true

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # As abas lidas neste envio, na ordem programação, produção, compras e por dia.
  def sorted_versions
    order = ReferenceSheet::KINDS
    versions.includes(:reference_sheet).sort_by { |v| [ order.index(v.reference_sheet.kind), v.reference_sheet.date ] }
  end
end
