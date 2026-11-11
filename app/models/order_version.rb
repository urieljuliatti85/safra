# Retrato do pedido de um cliente/semana depois de um salvamento que mudou alguma coisa (OrderGridSaver).
# lines: o pedido inteiro, [{ "product_id", "unit", "date", "quantity" }].
# changes_list: só o que mudou em relação à versão anterior, [{ "product_id", "product", "unit", "date", "before", "after" }].
class OrderVersion < ApplicationRecord
  # "copy" veio do botão "Copiar semana anterior", que foi retirado; fica para as versões já gravadas assim.
  SOURCES = {
    "initial" => "Antes do primeiro salvamento", "grid" => "Grade", "import" => "Planilha importada",
    "image" => "Pedido em imagem", "undo" => "Importação desfeita", "restore" => "Versão restaurada", "api" => "API",
    "copy" => "Copiado da semana anterior", "cancel" => "Item cancelado"
  }.freeze

  # Tipo de pedido escolhido por quem lança (R1.29 a R1.33, D22). O extra soma ao que já estava; os outros gravam o total.
  ENTRY_TYPES = { "new" => "Pedido novo", "alteration" => "Alteração", "extra" => "Extra" }.freeze

  acts_as_tenant :company

  belongs_to :order
  belongs_to :user, optional: true
  belongs_to :order_import, optional: true

  validates :version, presence: true, uniqueness: { scope: :order_id }
  validates :source, inclusion: { in: SOURCES.keys }
  validates :entry_type, inclusion: { in: ENTRY_TYPES.keys }, allow_nil: true

  scope :newest_first, -> { order(version: :desc) }

  def source_label
    label = SOURCES.fetch(source)
    label = "#{label} (v#{restored_from_version})" if restored_from_version
    label = "#{label} · #{ENTRY_TYPES.fetch(entry_type)}" if entry_type
    late_confirmed? ? "#{label} · confirmada com menos de 48 h" : label
  end

  def latest?
    order.versions.maximum(:version) == version
  end

  # { [product_id, unit, date] => quantity } do retrato.
  def quantities
    lines.to_h { |line| [ [ line["product_id"], line["unit"], Date.iso8601(line["date"]) ], BigDecimal(line["quantity"]) ] }
  end
end
