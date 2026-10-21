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

    # Setores com produção no dia, na ordem de Cut::SECTORS, mais "aprontes" se houver caixas a aprontar.
    def sectors
      present = items.map { |item| item.product.sector }
      Cut::SECTORS.select { |sector| present.include?(sector) } + (aprontes.any? ? [ APRONTES ] : [])
    end

    # Só a lista de um setor (ou só os aprontes), para a tela e o PDF de cada bancada.
    def for_sector(sector)
      return self if sector.blank?
      return with(items: []) if sector == APRONTES

      kept = items.select { |item| item.product.sector == sector }
      with(items: kept, delivery_dates: kept.flat_map { |item| item.breakdown.map(&:delivery_date) }.uniq.sort, aprontes: [])
    end
  end
  APRONTES = "aprontes".freeze

  def initialize(company:, date:)
    @company = company
    @date = date.to_date
  end

  def call
    ActsAsTenant.with_tenant(@company) { self.class.result(@date, build_items) }
  end

  # Linhas in natura entregues neste dia ou que contariam para ele pela antecedência:
  # não passam pela produção, vão direto para a compra.
  def raw_lines
    ActsAsTenant.with_tenant(@company) do
      window_lines.select do |line|
        line.product.raw? && (line.delivery_date == @date || line.product.production_date_for(line.delivery_date) == @date)
      end
    end
  end

  # Também monta a versão enviada (ProductionPlan#to_result): entregas e aprontes saem dos itens, não do pedido.
  def self.result(date, items)
    items = items.sort_by { |item| [ item.product.sector.to_s, item.product.name ] }
    Result.new(
      date: date,
      items: items,
      delivery_dates: items.flat_map { |item| item.breakdown.map(&:delivery_date) }.uniq.sort,
      aprontes: aprontes(items)
    )
  end

  def self.aprontes(items)
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
    end
  end

  def candidate_lines
    day_lines.reject { |line| line.product.raw? }
  end

  def day_lines
    window_lines.select { |line| line.product.production_date_for(line.delivery_date) == @date }
  end

  # Só entregas dentro da janela possível: produção é no máximo `lead_days` + fim de semana antes da entrega.
  def window_lines
    @window_lines ||= OrderLine.where("quantity > 0")
                               .where(delivery_date: @date..(@date + 7))
                               .includes({ order: :customer }, product: [ :cut, :production_rule, :raw_material ])
                               .to_a
  end
end
