# Compara o que os planners calculam com o que foi feito à mão nas planilhas
# (db/seeds_data/referencia_planilhas.yml). Devolve as diferenças em vez de falhar:
# ainda não conhecemos todas as regras (ver docs/duvidas.md).
class SheetComparison
  REFERENCE = Rails.root.join("db/seeds_data/referencia_planilhas.yml")

  ProductionRow = Struct.new(:date, :product, :sector, :cut, :planilha, :sistema, :status, keyword_init: true)
  PurchaseRow = Struct.new(:date, :raw_material, :planilha_text, :planilha, :sistema, :unit, :status, keyword_init: true)

  # Cortes cuja regra já está confirmada: produzidos no dia da entrega.
  CONFIRMED_SAME_DAY_CUTS = %w[ralado picado rodelas].freeze

  def initialize(company)
    @company = company
    @reference = YAML.safe_load_file(REFERENCE)
  end

  def production_rows
    @production_rows ||= @reference.fetch("producao_planilha").flat_map do |date_text, planilha|
      date = Date.parse(date_text)
      plan = ProductionPlanner.new(company: @company, date: date).call
      planner_items = plan.items.select { |item| item.unit == "kg" || item.product.unit != "kg" }.index_by { |item| item.product.code }
      ActsAsTenant.with_tenant(@company) do
        (planilha.keys | planner_items.keys).sort.map do |code|
          product = Product.includes(:cut).find_by!(code: code)
          expected = planilha[code]
          got = planner_items[code]&.quantity&.to_f
          ProductionRow.new(date: date, product: code, sector: product.sector, cut: product.cut&.code,
                            planilha: expected, sistema: got, status: status(expected, got))
        end
      end
    end
  end

  def purchase_rows
    @purchase_rows ||= begin
      result = PurchasePlanner.new(company: @company).call
      @reference.fetch("compras_ceasa_planilha").flat_map do |date_text, entries|
        date = Date.parse(date_text)
        planilha_codes = entries.map { |entry| entry["materia_prima"] }
        needs = result.purchases.fetch(date, [])
        rows = entries.map { |entry| purchase_row(date, entry, needs) }
        # Itens que o sistema compra e a planilha não tem.
        (needs.map { |n| n.raw_material.code }.uniq - planilha_codes).each do |code|
          unit = needs.find { |n| n.raw_material.code == code }.then { |n| n.unit }
          rows << PurchaseRow.new(date: date, raw_material: code, planilha_text: nil, planilha: nil,
                                  sistema: comparable_value(needs.select { |n| n.raw_material.code == code }, unit == "kg" ? "kg" : unit),
                                  unit: unit, status: "só no sistema")
        end
        rows
      end
    end
  end

  # Placar: [iguais, total]. O total é o que a planilha tem e dá para comparar (não muda com as regras);
  # itens que só o sistema calcula e textos que não são número não entram.
  def scores
    { production: score(production_rows), purchase: score(purchase_rows) }
  end

  def summary
    prod = production_rows.group_by(&:status).transform_values(&:size)
    purch = purchase_rows.group_by(&:status).transform_values(&:size)
    { producao: prod, compras: purch }
  end

  def confirmed_same_day_rows
    production_rows.select { |row| CONFIRMED_SAME_DAY_CUTS.include?(row.cut) }
  end

  def report
    lines = []
    lines << "CONFERÊNCIA COM AS PLANILHAS (13 e 15/10/2026)"
    lines << "=" * 60
    lines << ""
    lines << "PRODUÇÃO por dia e produto (kg, exceto laranja em un)"
    production_rows.group_by(&:date).each do |date, rows|
      lines << ""
      lines << "  #{date.strftime('%d/%m')} (#{rows.count { |r| r.status == 'ok' }}/#{rows.size} iguais)"
      rows.sort_by { |r| [ r.status == "ok" ? 1 : 0, r.sector.to_s, r.product ] }.each do |r|
        lines << format("    %-14s %-24s planilha=%-7s sistema=%-7s %s", r.sector, r.product, fmt(r.planilha), fmt(r.sistema), r.status)
      end
    end
    lines << ""
    lines << "COMPRAS CEASA por dia e matéria-prima"
    purchase_rows.group_by(&:date).each do |date, rows|
      lines << ""
      lines << "  #{date.strftime('%d/%m')} (#{rows.count { |r| r.status == 'ok' }}/#{rows.size} iguais)"
      rows.sort_by { |r| [ r.status == "ok" ? 1 : 0, r.raw_material ] }.each do |r|
        lines << format("    %-20s planilha=%-22s sistema=%-8s %s", r.raw_material, r.planilha_text || "-", fmt(r.sistema, r.unit), r.status)
      end
    end
    lines.join("\n")
  end

  private

  def score(rows)
    comparable = rows.select { |r| r.planilha }
    [ comparable.count { |r| r.status == "ok" }, comparable.size ]
  end

  def status(expected, got)
    return "só no sistema" if expected.nil?
    return "só na planilha" if got.nil?

    (expected - got).abs < 0.0005 ? "ok" : "diferente (#{format('%+g', got - expected)})"
  end

  def fmt(value, unit = nil)
    return "-" if value.nil?

    "#{value.to_f.round(1).to_s.sub(/\.0\z/, '')}#{unit ? " #{unit}" : ''}"
  end

  def purchase_row(date, entry, needs)
    text = entry["quantidade"].to_s
    quantity, unit = parse_quantity(text)
    mine = needs.select { |n| n.raw_material.code == entry["materia_prima"] }
    got = comparable_value(mine, unit) if unit
    PurchaseRow.new(date: date, raw_material: entry["materia_prima"], planilha_text: text, planilha: quantity,
                    sistema: got, unit: unit, status: quantity.nil? ? "texto não comparável" : status(quantity, got))
  end

  # "20 cx" -> [20.0, "cx"]. Textos compostos ("45 kg + 20 kg média") não são comparados.
  def parse_quantity(text)
    match = text.match(/\A\s*([\d.,]+)\s*(cx|sc|kg|g|un)\s*\z/)
    match ? [ match[1].tr(",", ".").to_f, match[2] ] : [ nil, nil ]
  end

  # Valor do sistema na mesma unidade que a planilha usou.
  def comparable_value(needs, unit)
    return nil if needs.empty?

    case unit
    when "cx", "sc"
      packaged = needs.select { |n| n.unit == "kg" }.filter_map(&:packages)
      same_unit = needs.select { |n| n.unit == unit }.sum { |n| n.raw_quantity + n.processed_quantity }
      return nil if packaged.empty? && same_unit.zero? # sem kg por embalagem: não dá para calcular

      (packaged.sum + same_unit).to_f
    when "kg" then needs.select { |n| n.unit == "kg" }.sum(&:net_kg).to_f
    when "g" then needs.select { |n| n.unit == "kg" }.sum(&:net_kg).to_f * 1000
    else needs.select { |n| n.unit == unit }.sum(&:kg).to_f
    end
  end
end
