# Retrato do pedido de um cliente/semana depois de um salvamento que mudou alguma coisa (OrderGridSaver).
# lines: o pedido inteiro, [{ "product_id", "unit", "date", "quantity" }].
# changes_list: só o que mudou em relação à versão anterior, [{ "product_id", "product", "unit", "date", "before", "after" }].
class OrderVersion < ApplicationRecord
  SOURCES = {
    "initial" => "Antes do primeiro salvamento", "grid" => "Grade", "import" => "Planilha importada",
    "image" => "Pedido em imagem", "undo" => "Importação desfeita", "restore" => "Versão restaurada", "api" => "API"
  }.freeze

  acts_as_tenant :company

  belongs_to :order
  belongs_to :user, optional: true
  belongs_to :order_import, optional: true

  validates :version, presence: true, uniqueness: { scope: :order_id }
  validates :source, inclusion: { in: SOURCES.keys }

  scope :newest_first, -> { order(version: :desc) }

  def source_label
    label = SOURCES.fetch(source)
    restored_from_version ? "#{label} (v#{restored_from_version})" : label
  end

  def latest?
    order.versions.maximum(:version) == version
  end

  # { [product_id, unit, date] => quantity } do retrato.
  def quantities
    lines.to_h { |line| [ [ line["product_id"], line["unit"], Date.iso8601(line["date"]) ], BigDecimal(line["quantity"]) ] }
  end
end
