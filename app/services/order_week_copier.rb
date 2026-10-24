# Copia o pedido da semana anterior do mesmo cliente para uma semana ainda vazia, com as entregas 7 dias depois.
# Clientes como hospitais e refeitórios pedem quase o mesmo toda semana: copia-se e ajusta-se só a diferença.
# Só copia para semana sem pedido, para nunca sobrescrever o que já foi digitado. Grava uma versão "copy".
class OrderWeekCopier
  def initialize(order:)
    @order = order
  end

  def previous_order
    @previous_order ||= Order.find_by(customer_id: @order.customer_id, week_start: @order.week_start - 7)
  end

  # Quantas linhas a semana anterior tem para copiar; zero quando não há o que copiar.
  def previous_lines_count
    previous_order ? previous_order.lines.where("quantity > 0").count : 0
  end

  def call
    return failure("Esta semana já tem pedido. Copiar só funciona numa semana vazia.") if @order.lines.exists?
    return failure("A semana de #{Formatting.short_date(@order.week_start - 7)} não tem pedido para copiar.") if previous_lines_count.zero?

    OrderGridSaver.new(order: @order, quantities: grid, source: "copy").call
  end

  private

  # { "<product_id>|<unit>" => { "AAAA-MM-DD" => "12" } } com as entregas da semana anterior mais 7 dias.
  def grid
    previous_order.lines.where("quantity > 0").group(:product_id, :unit, :delivery_date).sum(:quantity)
                  .each_with_object({}) do |((product_id, unit, date), quantity), grid|
      (grid["#{product_id}|#{unit}"] ||= {})[(date + 7).iso8601] = quantity.to_s("F").sub(/\.0\z/, "")
    end
  end

  def failure(message)
    OrderGridSaver::Result.new(errors: [ message ], changed_dates: [])
  end
end
