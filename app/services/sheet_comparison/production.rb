class SheetComparison
  # Produção (02 - PLANILHA DE PRODUÇÃO) contra o ProductionPlanner: cortes em kg, aprontes em caixas e o descascador.
  class Production < Section
    def initialize(**)
      super
      @plans = {}
    end

    def rows = sheets_of("production").flat_map { |sheet| rows_for(sheet) }

    private

    def plan(date) = @plans[date] ||= ProductionPlanner.new(company: @company, date: date).call

    def produced(date, product)
      items = plan(date).items.select { |item| item.product == product && item.unit == product.unit }
      items.empty? ? nil : items.sum(&:quantity)
    end

    def rows_for(sheet)
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

    # Quanto a planilha de produção de outro dia (entre as importadas) tem do produto.
    def sheet_quantity(date, product)
      @sheet_cuts ||= sheets_of("production").to_h do |sheet|
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
  end
end
