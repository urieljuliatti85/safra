# Um item como está na planilha: "CENOURA EM CUBINHOS" 23 kg, "BAROA DESCASCADA" "1 CX", "PEPINO" "1 cx".
# Na programação (01), cada linha diz também o cliente (group_label) e o dia de entrega.
class ReferenceSheetLine < ApplicationRecord
  SECTIONS = %w[programacao descascador aprontes cortes compras].freeze

  belongs_to :reference_sheet

  validates :section, inclusion: { in: SECTIONS }
  validates :label, presence: true

  # Programação e cortes viram produto; descascador, aprontes e compras viram matéria-prima.
  def target = %w[programacao cortes].include?(section) ? "product" : "raw_material"
end
