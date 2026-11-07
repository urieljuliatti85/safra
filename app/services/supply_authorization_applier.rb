# Grava uma AF (Autorização de Fornecimento) no pedido da semana da entrega (R1.27, D4).
# A alteração não gera AF nova: chega com o mesmo número e a lista inteira. As linhas que vieram daquela AF são
# trocadas pelas da alteração (produto que sumiu vai a zero); o resto do pedido não muda. Fica uma versão nova.
# items: [{ product:, unit:, quantity: }]
class SupplyAuthorizationApplier
  def initialize(customer:, number:, delivery_date:, items:, source: "import", import: nil, late_confirmed: false)
    @late_confirmed = late_confirmed
    @customer = customer
    @number = number.to_s.strip
    @date = delivery_date
    @items = items
    @source = source
    @import = import
  end

  def call
    order = Order.find_or_create_by!(customer: @customer, week_start: @date.beginning_of_week)
    quantities = Hash.new { |hash, key| hash[key] = {} }
    order.lines.where(af_number: @number).find_each do |line|
      quantities["#{line.product_id}|#{line.unit}"][line.delivery_date.iso8601] = "0"
    end
    @items.each do |item|
      quantities["#{item[:product].id}|#{item[:unit]}"][@date.iso8601] = item[:quantity].to_s
    end

    result = nil
    Order.transaction do
      result = OrderGridSaver.new(order: order, quantities: quantities, source: @source, import: @import, late_confirmed: @late_confirmed).call
      raise ActiveRecord::Rollback unless result.ok?

      @items.each do |item|
        order.lines.where(product: item[:product], unit: item[:unit], delivery_date: @date).update_all(af_number: @number)
      end
    end
    result
  end
end
