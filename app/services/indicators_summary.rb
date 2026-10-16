# Indicadores de uma semana (segunda a domingo) para a tela de Indicadores: volume por dia e por setor, perdas por
# matéria-prima, compras por fornecedor e clientes e produtos mais pedidos. Lê as mesmas tabelas planas da API de BI
# (BiReport), então tela e API sempre concordam. Totais só em kg; outras unidades são contadas à parte.
class IndicatorsSummary
  TOP = 8

  Day = Data.define(:date, :kg, :share)
  Bar = Data.define(:label, :kg, :share)
  Loss = Data.define(:name, :processed_kg, :raw_kg, :loss_kg, :pct, :share)
  Supplier = Data.define(:name, :gross_kg, :stock_kg, :net_kg, :share)
  Result = Data.define(:week_start, :days, :sectors, :losses, :suppliers, :customers, :products, :production_kg, :loss_kg,
                       :loss_pct, :net_purchase_kg, :customer_count, :without_factor, :other_unit_lines, :empty) do
    def week_end = week_start + 6
  end

  def initialize(company:, date:)
    @company = company
    @week_start = date.beginning_of_week
  end

  def call
    ActsAsTenant.with_tenant(@company) { build }
  end

  private

  def build
    report = BiReport.new(company: @company, from: @week_start, to: @week_start + 6)
    production = kg_only(report.production)
    schedule = report.schedule
    losses = report.losses
    suppliers = kg_only(report.purchases)
    loss_rows = loss_rows(losses)
    Result.new(
      week_start: @week_start, days: days(production), sectors: bars(production, :sector_name, fallback: :sector),
      losses: loss_rows, suppliers: supplier_rows(suppliers),
      customers: bars(kg_only(schedule), :customer_name), products: bars(kg_only(schedule), :product_name),
      production_kg: production.sum { |r| r[:quantity] }, loss_kg: losses.sum { |r| r[:loss_kg] },
      loss_pct: loss_pct(losses), net_purchase_kg: suppliers.sum { |r| r[:net_kg] },
      customer_count: schedule.map { |r| r[:customer] }.uniq.size,
      without_factor: (production.map { |r| r[:product] }.uniq - losses.map { |r| r[:product] }).size,
      other_unit_lines: schedule.count { |r| r[:unit] != "kg" },
      empty: production.empty? && schedule.empty? && suppliers.empty?
    )
  end

  def kg_only(rows) = rows.select { |r| r.fetch(:unit) == "kg" }

  def share(value, max) = max.to_f.positive? ? value / max : 0.0

  def days(production)
    totals = production.group_by { |r| Date.iso8601(r[:production_date]) }.transform_values { |rows| rows.sum { |r| r[:quantity] } }
    max = totals.values.max
    (@week_start..(@week_start + 6)).map { |date| Day.new(date: date, kg: totals.fetch(date, 0.0), share: share(totals.fetch(date, 0.0), max)) }
  end

  def bars(rows, key, fallback: nil)
    totals = rows.group_by { |r| r[key] || (fallback && r[fallback]) || "Sem nome" }.transform_values { |group| group.sum { |r| r[:quantity] } }
    top = totals.sort_by { |label, kg| [ -kg, label ] }.first(TOP)
    max = top.first&.last
    top.map { |label, kg| Bar.new(label: label, kg: kg, share: share(kg, max)) }
  end

  def loss_rows(losses)
    grouped = losses.group_by { |r| r[:raw_material_name] }.map do |name, rows|
      processed = rows.sum { |r| r[:processed_kg] }
      raw = rows.sum { |r| r[:raw_kg] }
      [ name, processed, raw, raw - processed ]
    end.sort_by { |name, _, _, loss| [ -loss, name ] }.first(12)
    max_raw = grouped.map { |_, _, raw, _| raw }.max
    grouped.map do |name, processed, raw, loss|
      pct = raw.positive? ? loss / raw * 100 : 0.0
      Loss.new(name: name, processed_kg: processed, raw_kg: raw, loss_kg: loss, pct: pct, share: share(raw, max_raw)) # largura = kg in natura
    end
  end

  def loss_pct(losses)
    raw = losses.sum { |r| r[:raw_kg] }
    raw.positive? ? (raw - losses.sum { |r| r[:processed_kg] }) / raw * 100 : 0.0
  end

  def supplier_rows(rows)
    grouped = rows.group_by { |r| r[:supplier] || "Sem fornecedor" }.map do |name, group|
      [ name, group.sum { |r| r[:gross_kg] }, group.sum { |r| r[:stock_kg] }, group.sum { |r| r[:net_kg] } ]
    end.sort_by { |name, _, _, net| [ -net, name ] }
    max = grouped.map { |_, gross, _, _| gross }.max
    grouped.map { |name, gross, stock, net| Supplier.new(name: name, gross_kg: gross, stock_kg: stock, net_kg: net, share: share(gross, max)) }
  end
end
