# Calcula a produção de um dia: o que produzir por produto (com a abertura por cliente e entrega)
# e as caixas a aprontar por matéria-prima. Nada é digitado: tudo sai das linhas de pedido.
# Referência: funções producao() e aprontes() de prototipo/safra.html.
class ProductionPlanner
  Item = Data.define(:product, :quantity, :unit, :breakdown)
  Breakdown = Data.define(:customer, :delivery_date, :quantity)
  # Caixas a aprontar (descascadas) por matéria-prima.
  Apronte = Data.define(:raw_material, :kg, :boxes)
  Result = Data.define(:date, :items, :delivery_dates, :aprontes) do
    def item_for(product_code)
      items.find { |item| item.product.code == product_code }
    end
  end

  def initialize(company:, date:)
    @company = company
    @date = date.to_date
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      items = build_items
      Result.new(
        date: @date,
        items: items,
        delivery_dates: items.flat_map { |item| item.breakdown.map(&:delivery_date) }.uniq.sort,
        aprontes: build_aprontes(items)
      )
    end
  end

  private

  def build_items
    grouped = candidate_lines.group_by { |line| [ line.product, line.unit ] }
    grouped.map do |(product, unit), lines|
      Item.new(
        product: product,
        quantity: lines.sum(&:quantity),
        unit: unit,
        breakdown: lines.sort_by { |l| [ l.delivery_date, l.order.customer.code ] }.map do |line|
          Breakdown.new(customer: line.order.customer, delivery_date: line.delivery_date, quantity: line.quantity)
        end
      )
    end.sort_by { |item| [ item.product.sector.to_s, item.product.name ] }
  end

  # Só entregas dentro da janela possível: produção é no máximo `lead_days` + fim de semana antes da entrega.
  def candidate_lines
    OrderLine.where("quantity > 0")
             .where(delivery_date: @date..(@date + 7))
             .includes(:order, product: [ :cut, :production_rule ])
             .select { |line| !line.product.raw? && line.product.production_date_for(line.delivery_date) == @date }
  end

  def build_aprontes(items)
    by_raw_material = Hash.new(0)
    items.each do |item|
      product = item.product
      next unless item.unit == "kg" && product.sector != "descasc"
      next if product.raw_material.kg_per_peeled_box.blank?

      by_raw_material[product.raw_material] += item.quantity
    end
    by_raw_material.map do |raw_material, kg|
      Apronte.new(raw_material: raw_material, kg: kg, boxes: (kg / raw_material.kg_per_peeled_box).round)
    end.sort_by { |apronte| apronte.raw_material.name }
  end
end
