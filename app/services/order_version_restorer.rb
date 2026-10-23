# Volta o pedido ao retrato de uma versão: o que não estava nela é apagado, o que estava volta à quantidade de então.
# Restaurar não apaga versões: grava uma nova ("Versão restaurada (vN)"). Apelidos não mudam.
class OrderVersionRestorer
  def initialize(version:)
    @version = version
    @order = version.order
  end

  def call
    return OrderGridSaver::Result.new(errors: [ "Esta já é a versão atual do pedido." ], changed_dates: []) if @version.latest?

    OrderGridSaver.new(order: @order, quantities: grid, source: "restore", restored_from: @version.version).call
  end

  private

  # { "<product_id>|<unit>" => { "AAAA-MM-DD" => "12" } } com todas as células do pedido de hoje e da versão.
  def grid
    existing = Product.where(id: @version.lines.map { |line| line["product_id"] }).ids
    target = @version.quantities.select { |(product_id, _, _), _| existing.include?(product_id) }
    current = @order.lines.group(:product_id, :unit, :delivery_date).sum(:quantity).select { |_, quantity| quantity.positive? }
    (current.keys | target.keys).each_with_object({}) do |(product_id, unit, date), grid|
      quantity = target[[ product_id, unit, date ]]
      (grid["#{product_id}|#{unit}"] ||= {})[date.iso8601] = quantity ? quantity.to_s("F").sub(/\.0\z/, "") : ""
    end
  end
end
