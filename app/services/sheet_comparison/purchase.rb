class SheetComparison
  # Compras (03 - COMPRAS CEASA) contra o PurchasePlanner, na unidade que a planilha usou (caixa, saco, kg ou g).
  class Purchase < Section
    def rows = sheets_of("purchase").flat_map { |sheet| rows_for(sheet) }

    private

    def purchases = @purchases ||= PurchasePlanner.new(company: @company).call.purchases

    def purchase_days = @purchase_days ||= PurchaseDay.pluck(:date).to_set

    def rows_for(sheet)
      groups = classify(sheet)
      sheet_items = groups.filter_map { |(section, raw_material), lines| [ raw_material, lines ] if section == "compras" }.to_h
      needs = purchases.fetch(sheet.date, []).group_by(&:raw_material)
      rows = (sheet_items.keys | needs.keys).map do |raw_material|
        row(sheet.date, raw_material, sheet_items[raw_material], needs.fetch(raw_material, []))
      end
      rows + unmatched_rows(:purchase, sheet, groups)
    end

    def row(date, raw_material, lines, needs)
      units = lines.to_a.map(&:unit).uniq
      unit = units.size == 1 && units.first ? units.first : system_unit(raw_material, needs)
      planilha, text = total(lines, unit)
      sistema = comparable_value(needs, unit) if purchase_days.include?(date)
      status = status_for(planilha, text, sistema)
      reason, detail = reason_for(status, date, raw_material, needs, unit, planilha, sistema)
      Row.new(kind: :purchase, section: "compras", date: date, record: raw_material, label: raw_material.name, planilha: planilha,
              planilha_text: text, sistema: sistema, unit: unit, status: status, reason: reason, detail: detail)
    end

    def reason_for(status, date, raw_material, needs, unit, planilha, sistema)
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
  end
end
