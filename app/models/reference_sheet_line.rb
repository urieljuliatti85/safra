# Um item como está na planilha: "CENOURA EM CUBINHOS" 23 kg, "BAROA DESCASCADA" "1 CX", "PEPINO" "1 cx".
class ReferenceSheetLine < ApplicationRecord
  SECTIONS = %w[descascador aprontes cortes compras].freeze

  belongs_to :reference_sheet

  validates :section, inclusion: { in: SECTIONS }
  validates :label, presence: true

  # Cortes viram produto; descascador, aprontes e compras viram matéria-prima.
  def target = section == "cortes" ? "product" : "raw_material"
end
