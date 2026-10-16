# Compara o que os planners calculam com o que foi feito à mão nas planilhas importadas (ReferenceSheet: abas da
# 02 - PLANILHA DE PRODUÇÃO e da 03 - COMPRAS CEASA). Devolve as diferenças, cada uma com o motivo provável, em vez
# de falhar: ainda não conhecemos todas as regras (ver docs/duvidas.md).
class SheetComparison
  STATUS_LABELS = {
    ok: "igual", different: "diferente", only_sheet: "só na planilha", only_system: "só no sistema",
    not_comparable: "não comparável", unmatched: "nome não reconhecido"
  }.freeze

  REASONS = {
    lead_time: "Outro dia de produção (antecedência)",
    no_order: "Nenhum pedido no Safra leva a isso",
    follows_cuts: "Segue a diferença nos cortes",
    descasc_sector: "Descascado inteiro: a planilha anota no descascador",
    not_modeled: "O Safra ainda não calcula o descascador",
    missing_box: "Falta kg por caixa descascada no cadastro",
    missing_package: "Falta kg por embalagem no cadastro",
    missing_factor: "Falta fator de rendimento no cadastro",
    other_unit: "O pedido está em outra unidade",
    stock: "Estoque da câmara fria abatido",
    rounding: "Diferença de 1 embalagem",
    not_purchase_day: "Não é dia de compra no Safra",
    not_in_sheet: "Não está na planilha",
    text: "Quantidade em texto",
    unmatched: "Ligue o nome a um item do cadastro",
    unexplained: "Sem regra que explique"
  }.freeze

  # Motivos que apontam para o cadastro da matéria-prima.
  CATALOG_REASONS = %i[missing_box missing_package missing_factor].freeze

  # Cortes cuja regra já está confirmada: produzidos no dia da entrega.
  CONFIRMED_SAME_DAY_CUTS = %w[ralado picado rodelas].freeze
  NEIGHBOR_DAYS = 3

  SECTION_LABELS = { "cortes" => "Cortes", "aprontes" => "Aprontes", "descascador" => "Descascador", "compras" => "Compras" }.freeze

  Row = Data.define(:kind, :section, :date, :record, :label, :planilha, :planilha_text, :sistema, :unit, :status, :reason, :detail) do
    def ok? = status == :ok
    def code = record&.code
    def key = [ kind, section, date, code || label ]
    def different? = %i[different only_sheet only_system].include?(status)
    # Entra no placar: a planilha tem um número e o item foi reconhecido.
    def scored? = %i[ok different only_sheet].include?(status) && !planilha.nil?
    def explained? = reason.present? && reason != :unexplained
    def status_label = SheetComparison::STATUS_LABELS.fetch(status)
    def reason_label = reason && SheetComparison::REASONS.fetch(reason)
    def difference = planilha && sistema && (sistema - planilha)
    def cut_code = record.is_a?(Product) ? record.cut&.code : nil
  end

  Unmatched = Data.define(:target, :label, :lines)

  def initialize(company, dates: nil)
    @company = company
    @dates = dates
    @plans = {}
  end

  def sheets
    @sheets ||= with_tenant do
      scope = ReferenceSheet.includes(:lines).order(:kind, :date)
      scope = scope.where(date: @dates) if @dates
      scope.to_a
    end
  end

  def production_rows
    @production_rows ||= with_tenant { sheets.select { |s| s.kind == "production" }.flat_map { |sheet| production_rows_for(sheet) } }
  end

  def purchase_rows
    @purchase_rows ||= with_tenant { sheets.select { |s| s.kind == "purchase" }.flat_map { |sheet| purchase_rows_for(sheet) } }
  end

  def rows = production_rows + purchase_rows

  # Placar: [iguais, total]. O total é o que a planilha tem e dá para comparar (não muda com as regras);
  # itens que só o sistema calcula, textos que não são número e nomes não reconhecidos não entram.
  def scores
    { production: score(production_rows), purchase: score(purchase_rows) }
  end

  # Diferenças que entram no placar, por motivo: [[motivo, quantidade]], o mais comum primeiro.
  def reasons
    rows.select { |row| row.scored? && !row.ok? }.group_by(&:reason).map { |reason, list| [ reason, list.size ] }.sort_by { |_, n| -n }
  end

  def explained_count = rows.count { |row| row.scored? && !row.ok? && row.explained? }

  # Nomes da planilha que ainda não estão ligados a nada, um por nome (com as linhas onde aparecem).
  def unmatched
    @unmatched ||= with_tenant do
      sheets.flat_map { |sheet| sheet.lines.map { |line| [ sheet, line ] } }
            .reject { |_, line| matcher.call(line.label, line.target) }
            .group_by { |_, line| [ line.target, ReferenceSheets::Matcher.key(line.label) ] }
            .map { |(target, _), pairs| Unmatched.new(target: target, label: pairs.first.last.label, lines: pairs) }
            .sort_by { |item| [ item.target, item.label ] }
    end
  end

  def summary
    { producao: production_rows.group_by(&:status_label).transform_values(&:size),
      compras: purchase_rows.group_by(&:status_label).transform_values(&:size) }
  end

  def confirmed_same_day_rows
    with_tenant { production_rows.select { |row| row.section == "cortes" && CONFIRMED_SAME_DAY_CUTS.include?(row.cut_code) } }
  end

  def report
    lines = [ "CONFERÊNCIA COM AS PLANILHAS (#{sheets.map(&:date).uniq.sort.map { |d| d.strftime('%d/%m') }.join(', ')})", "=" * 60 ]
    { "PRODUÇÃO" => production_rows, "COMPRAS CEASA" => purchase_rows }.each do |title, list|
      lines << "" << title
      list.group_by(&:date).each do |date, day_rows|
        lines << "" << "  #{date.strftime('%d/%m')} (#{day_rows.count(&:ok?)}/#{day_rows.count(&:scored?)} iguais)"
        day_rows.sort_by { |r| [ r.ok? ? 1 : 0, r.section, r.label ] }.each do |r|
          lines << format("    %-12s %-28s planilha=%-14s sistema=%-10s %-16s %s", r.section, r.label.truncate(28), r.planilha_text || fmt(r.planilha, r.unit),
                          fmt(r.sistema, r.unit), r.status_label, [ r.reason_label, r.detail ].compact.join(": "))
        end
      end
    end
    lines.join("\n")
  end

  private

  def with_tenant(&) = ActsAsTenant.with_tenant(@company, &)

  def matcher = @matcher ||= ReferenceSheets::Matcher.new

  def score(list)
    scored = list.select(&:scored?)
    [ scored.count(&:ok?), scored.size ]
  end

  # Linhas reconhecidas agrupadas por seção e item; as não reconhecidas vão em :unmatched. Ignoradas somem.
  def classify(sheet)
    sheet.lines.each_with_object(Hash.new { |h, k| h[k] = [] }) do |line, groups|
      match = matcher.call(line.label, line.target)
      next if match&.ignored

      groups[match ? [ line.section, match.record ] : [ :unmatched, line ]] << line
    end
  end

  # [quantidade somada, texto]: com qualquer linha em texto (ou em outra unidade), a soma não vale e fica o texto.
  def total(lines, unit = nil)
    return [ nil, nil ] if lines.blank?

    numeric = lines.all? { |line| line.quantity && (unit.nil? || line.unit == unit) }
    numeric ? [ lines.sum(&:quantity), nil ] : [ nil, lines.map(&:quantity_text).join(" + ") ]
  end

  def status_for(planilha, text, sistema)
    return :not_comparable if planilha.nil? && text
    return :only_system if planilha.nil?
    return :only_sheet if sistema.nil?

    (planilha - sistema).abs < 0.0005 ? :ok : :different
  end

  # --- Produção -------------------------------------------------------------------------------------------------

  def plan(date) = @plans[date] ||= ProductionPlanner.new(company: @company, date: date).call

  def produced(date, product)
    items = plan(date).items.select { |item| item.product == product && item.unit == product.unit }
    items.empty? ? nil : items.sum(&:quantity)
  end

  def production_rows_for(sheet)
    groups = classify(sheet)
    sections = groups.keys.map(&:first).uniq
    rows = []
    rows.concat(cut_rows(sheet, groups)) if sections.include?("cortes")
    rows.concat(apronte_rows(sheet, groups, rows)) if sections.include?("aprontes")
    groups.select { |(section, _), _| section == "descascador" }.each do |(_, raw_material), lines|
      quantity, text = total(lines)
      rows << Row.new(kind: :production, section: "descascador", date: sheet.date, record: raw_material, label: raw_material.name, planilha: quantity,
                      planilha_text: text || lines.map(&:quantity_text).join(" + "), sistema: nil, unit: "cx", status: :not_comparable, reason: :not_modeled, detail: nil)
    end
    rows + unmatched_rows(:production, sheet, groups)
  end

  def cut_rows(sheet, groups)
    sheet_products = groups.filter_map { |(section, product), lines| [ product, lines ] if section == "cortes" }.to_h
    products = (sheet_products.keys | plan(sheet.date).items.map(&:product)).uniq
    products.filter_map do |product|
      planilha, text = total(sheet_products[product])
      sistema = produced(sheet.date, product)
      next if planilha.nil? && text.nil? && sistema.nil?

      status = status_for(planilha, text, sistema)
      reason, detail = cut_reason(status, sheet.date, product, planilha, sistema)
      Row.new(kind: :production, section: "cortes", date: sheet.date, record: product, label: product.name, planilha: planilha, planilha_text: text,
              sistema: sistema, unit: product.unit, status: status, reason: reason, detail: detail)
    end
  end

  def cut_reason(status, date, product, planilha, sistema)
    return [ nil, nil ] if status == :ok
    return [ :text, nil ] if status == :not_comparable
    return [ :descasc_sector, nil ] if status == :only_system && product.sector == "descasc"

    detail = shifted_day(status, date, product, planilha, sistema)
    return [ :lead_time, detail ] if detail
    return [ :not_in_sheet, nil ] if status == :only_system
    return [ :no_order, nil ] if status == :only_sheet && neighbor_days(date).none? { |day| produced(day, product) }

    [ :unexplained, nil ]
  end

  # A diferença é só de dia quando o mesmo número aparece em outro dia: o que a planilha faz hoje o Safra faz num
  # dia vizinho (ou divide entre hoje e o dia ao lado), ou o que o Safra faz hoje a planilha fez num dia vizinho.
  def shifted_day(status, date, product, planilha, sistema)
    unit = product.unit
    if status == :only_system
      day = neighbor_days(date).find { |d| same?(sheet_quantity(d, product), sistema) }
      return day && "a planilha faz #{fmt(sistema, unit)} em #{day.strftime('%d/%m')}"
    end

    neighbor_days(date).each do |day|
      other = produced(day, product) or next
      return "o Safra faz #{fmt(other, unit)} em #{day.strftime('%d/%m')}" if same?(other, planilha)
      if sistema && (day - date).abs <= 2 && same?(other + sistema, planilha)
        return "o Safra divide: #{fmt(sistema, unit)} em #{date.strftime('%d/%m')} e #{fmt(other, unit)} em #{day.strftime('%d/%m')}"
      end
    end
    nil
  end

  def same?(a, b) = a && b && (a - b).abs < 0.0005

  def neighbor_days(date) = ((date - NEIGHBOR_DAYS)..(date + NEIGHBOR_DAYS)).reject { |day| day == date || day.sunday? }

  # Quanto a planilha de produção de outro dia (entre as importadas) tem do produto.
  def sheet_quantity(date, product)
    @sheet_cuts ||= sheets.select { |s| s.kind == "production" }.to_h do |sheet|
      [ sheet.date, classify(sheet).filter_map { |(section, record), lines| [ record, total(lines).first ] if section == "cortes" }.to_h ]
    end
    @sheet_cuts.dig(date, product)
  end

  def apronte_rows(sheet, groups, cut_rows)
    sheet_boxes = groups.filter_map { |(section, raw_material), lines| [ raw_material, lines ] if section == "aprontes" }.to_h
    system_boxes = plan(sheet.date).aprontes.to_h { |apronte| [ apronte.raw_material, apronte.boxes ] }
    (sheet_boxes.keys | system_boxes.keys).map do |raw_material|
      planilha, text = total(sheet_boxes[raw_material], "cx")
      sistema = system_boxes[raw_material]
      status = status_for(planilha, text, sistema)
      reason = apronte_reason(status, raw_material, cut_rows)
      Row.new(kind: :production, section: "aprontes", date: sheet.date, record: raw_material, label: raw_material.name, planilha: planilha,
              planilha_text: text, sistema: sistema, unit: "cx", status: status, reason: reason, detail: nil)
    end
  end

  def apronte_reason(status, raw_material, cut_rows)
    return nil if status == :ok
    return :text if status == :not_comparable
    return :missing_box if raw_material.kg_per_peeled_box.blank?
    return :follows_cuts if cut_rows.any? { |row| row.record.raw_material == raw_material && !row.ok? }
    return :not_in_sheet if status == :only_system

    :unexplained
  end

  def unmatched_rows(kind, sheet, groups)
    groups.select { |(section, _), _| section == :unmatched }.map do |(_, line), _|
      Row.new(kind: kind, section: line.section, date: sheet.date, record: nil, label: line.label, planilha: line.quantity,
              planilha_text: line.quantity.nil? ? line.quantity_text : nil, sistema: nil, unit: line.unit, status: :unmatched, reason: :unmatched, detail: nil)
    end
  end

  # --- Compras --------------------------------------------------------------------------------------------------

  def purchases = @purchases ||= PurchasePlanner.new(company: @company).call.purchases

  def purchase_days = @purchase_days ||= PurchaseDay.pluck(:date).to_set

  def purchase_rows_for(sheet)
    groups = classify(sheet)
    sheet_items = groups.filter_map { |(section, raw_material), lines| [ raw_material, lines ] if section == "compras" }.to_h
    needs = purchases.fetch(sheet.date, []).group_by(&:raw_material)
    rows = (sheet_items.keys | needs.keys).map do |raw_material|
      purchase_row(sheet.date, raw_material, sheet_items[raw_material], needs.fetch(raw_material, []))
    end
    rows + unmatched_rows(:purchase, sheet, groups)
  end

  def purchase_row(date, raw_material, lines, needs)
    units = lines.to_a.map(&:unit).uniq
    unit = units.size == 1 && units.first ? units.first : system_unit(raw_material, needs)
    planilha, text = total(lines, unit)
    sistema = comparable_value(needs, unit) if purchase_days.include?(date)
    status = status_for(planilha, text, sistema)
    reason, detail = purchase_reason(status, date, raw_material, needs, unit, planilha, sistema)
    Row.new(kind: :purchase, section: "compras", date: date, record: raw_material, label: raw_material.name, planilha: planilha,
            planilha_text: text, sistema: sistema, unit: unit, status: status, reason: reason, detail: detail)
  end

  def purchase_reason(status, date, raw_material, needs, unit, planilha, sistema)
    return [ nil, nil ] if status == :ok
    return [ :text, nil ] if status == :not_comparable
    return [ :not_purchase_day, "cadastre #{date.strftime('%d/%m')} em Compras" ] unless purchase_days.include?(date)
    return [ :not_in_sheet, "outro fornecedor, estoque ou outra compra?" ] if status == :only_system
    return [ :no_order, nil ] if needs.empty?
    return [ :other_unit, "Safra: #{needs.map { |n| fmt(n.kg, n.unit) }.join(' + ')}" ] if needs.none? { |n| n.unit == unit || (n.unit == "kg" && unit != "un") }
    return [ :missing_package, nil ] if %w[cx sc].include?(unit) && raw_material.kg_per_package.blank? && needs.any? { |n| n.unit == "kg" }
    return [ :missing_factor, nil ] if needs.any?(&:missing_factor)

    stock = needs.sum(&:stock_kg)
    return [ :stock, "#{fmt(stock, 'kg')} abatidos" ] if stock.positive?
    return [ :rounding, nil ] if %w[cx sc].include?(unit) && planilha && sistema && (planilha - sistema).abs <= 1

    [ :unexplained, nil ]
  end

  # Unidade para mostrar o que só o sistema compra: a embalagem de compra quando dá para calcular, senão a do pedido.
  def system_unit(raw_material, needs)
    return needs.first&.unit || "kg" unless needs.any? { |n| n.unit == "kg" }

    %w[cx sc].include?(raw_material.purchase_package) && raw_material.kg_per_package.present? ? raw_material.purchase_package : "kg"
  end

  # Valor do sistema na mesma unidade que a planilha usou.
  def comparable_value(needs, unit)
    return nil if needs.empty?

    case unit
    when "cx", "sc"
      packaged = needs.select { |n| n.unit == "kg" }.filter_map(&:packages)
      same_unit = needs.select { |n| n.unit == unit }.sum { |n| n.raw_quantity + n.processed_quantity }
      return nil if packaged.empty? && same_unit.zero? # sem kg por embalagem: não dá para calcular

      (packaged.sum + same_unit).to_d
    when "kg" then needs.select { |n| n.unit == "kg" }.sum(&:net_kg).to_d
    when "g" then needs.select { |n| n.unit == "kg" }.sum(&:net_kg).to_d * 1000
    else needs.select { |n| n.unit == unit }.then { |same| same.empty? ? nil : same.sum(&:kg).to_d }
    end
  end

  def fmt(value, unit = nil)
    return "-" if value.nil?

    "#{Formatting.qty(value)}#{unit ? " #{unit}" : ''}"
  end
end
