# Tabelas planas (uma linha por fato) para BI e painéis: programação, produção, compras e perdas num período.
# Tudo é calculado pelos mesmos serviços das telas; nada é digitado. Perda = kg in natura − kg processado.
class BiReport
  MAX_DAYS = 92
  DATASETS = {
    schedule: %i[delivery_date customer customer_name product product_name group quantity unit production_date],
    production: %i[production_date sector sector_name product product_name raw_material raw_material_name customer delivery_date quantity unit],
    purchases: %i[purchase_date supplier raw_material raw_material_name unit gross_kg stock_kg net_kg packages package missing_factor],
    losses: %i[production_date sector product product_name raw_material raw_material_name processed_kg raw_kg loss_kg loss_pct]
  }.freeze

  def initialize(company:, from:, to:)
    @company = company
    @from = from
    @to = to
  end

  def columns(dataset) = DATASETS.fetch(dataset)

  def rows(dataset) = public_send(dataset)

  def schedule
    days.flat_map do |date|
      ScheduleBuilder.new(company: @company, date: date).call.flat_map do |group|
        group.entries.map do |e|
          { delivery_date: date.iso8601, customer: group.customer.code, customer_name: group.customer.name,
            product: e.product.code, product_name: e.product.name, group: e.product.product_group,
            quantity: num(e.quantity), unit: e.unit, production_date: e.production_date&.iso8601 }
        end
      end
    end
  end

  def production
    productions.flat_map do |result|
      result.items.flat_map do |item|
        item.breakdown.map do |b|
          { production_date: result.date.iso8601, sector: item.product.sector, sector_name: item.product.cut&.sector_name,
            product: item.product.code, product_name: item.product.name, raw_material: item.product.raw_material.code,
            raw_material_name: item.product.raw_material.name, customer: b.customer.code, delivery_date: b.delivery_date.iso8601, quantity: num(b.quantity), unit: item.unit }
        end
      end
    end
  end

  def purchases
    plan = ActsAsTenant.with_tenant(@company) { PurchasePlanner.new(company: @company).call }
    plan.purchases.select { |date, _| date.between?(@from, @to) }.sort.flat_map do |date, needs|
      needs.map do |n|
        { purchase_date: date.iso8601, supplier: n.raw_material.supplier&.name, raw_material: n.raw_material.code,
          raw_material_name: n.raw_material.name, unit: n.unit, gross_kg: num(n.kg), stock_kg: num(n.stock_kg),
          net_kg: num(n.net_kg), packages: n.packages, package: n.raw_material.purchase_package, missing_factor: n.missing_factor }
      end
    end
  end

  # Só produtos em kg com fator cadastrado: sem fator não há como medir a perda.
  def losses
    productions.flat_map do |result|
      result.items.filter_map do |item|
        factor = item.product.raw_material.multiply_factor
        next unless item.unit == "kg" && factor && item.quantity.positive?

        raw_kg = item.quantity * factor
        loss = raw_kg - item.quantity
        { production_date: result.date.iso8601, sector: item.product.sector, product: item.product.code,
          product_name: item.product.name, raw_material: item.product.raw_material.code,
          raw_material_name: item.product.raw_material.name, processed_kg: num(item.quantity), raw_kg: num(raw_kg), loss_kg: num(loss), loss_pct: num((loss / raw_kg * 100).round(1)) }
      end
    end
  end

  private

  def days = (@from..@to).to_a

  def productions
    @productions ||= days.map { |date| ProductionPlanner.new(company: @company, date: date).call }
  end

  def num(value) = value&.to_f
end
