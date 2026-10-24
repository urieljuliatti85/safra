class SheetComparison
  # Programação (01 - PROG. DE PRODUÇÃO) contra os pedidos: cada cliente e dia de entrega vale pela aba mais recente que o traz.
  class Schedule < Section
    def rows
      blocks = schedule_blocks
      return [] if blocks.empty?

      dates = blocks.keys.map(&:last)
      @ordered = OrderLine.where("quantity > 0").where(delivery_date: (dates.min - NEIGHBOR_DAYS)..(dates.max + NEIGHBOR_DAYS))
                          .includes(:product, order: :customer).reject { |line| line.product.raw? }
                          .group_by { |line| [ line.order.customer, line.delivery_date, line.product ] }
      blocks.sort_by { |(customer, delivery), _| [ delivery, customer.short_name ] }.flat_map do |(customer, delivery), lines|
        block_rows(customer, delivery, lines)
      end
    end

    private

    def schedule_blocks
      sheets_of("schedule").sort_by(&:date).each_with_object({}) do |sheet, blocks|
        sheet.lines.group_by { |line| [ line.group_label, line.delivery_date ] }.each do |(label, delivery), lines|
          next if delivery.nil? || (@dates && !@dates.cover?(delivery))

          customer = matcher.call(label, "customer")
          blocks[[ customer.record, delivery ]] = lines if customer && !customer.ignored
        end
      end
    end

    def block_rows(customer, delivery, lines)
      matched, unmatched = lines.partition { |line| matcher.call(line.label, "product") }
      matched = matched.reject { |line| matcher.call(line.label, "product").ignored }.group_by { |line| matcher.call(line.label, "product").record }
      products = matched.keys | @ordered.keys.filter_map { |c, d, product| product if c == customer && d == delivery }
      sheet_totals = matched.transform_values { |list| total(list).first }
      rows = products.map do |product|
        planilha, text = total(matched[product])
        sistema = ordered(customer, delivery, product)
        status = status_for(planilha, text, sistema)
        reason, detail = reason_for(status, customer, delivery, product, planilha, sistema, sheet_totals)
        Row.new(kind: :schedule, section: customer.short_name, date: delivery, record: product, label: product.name, planilha: planilha,
                planilha_text: text, sistema: sistema, unit: product.unit, status: status, reason: reason, detail: detail)
      end
      rows + unmatched.map do |line|
        Row.new(kind: :schedule, section: customer.short_name, date: delivery, record: nil, label: line.label, planilha: line.quantity,
                planilha_text: line.quantity.nil? ? line.quantity_text : nil, sistema: nil, unit: nil, status: :unmatched, reason: :unmatched, detail: nil)
      end
    end

    # Quanto o cliente pediu no Safra, na unidade do produto.
    def ordered(customer, date, product)
      lines = @ordered.fetch([ customer, date, product ], []).select { |line| line.unit == product.unit }
      lines.empty? ? nil : lines.sum(&:quantity)
    end

    def reason_for(status, customer, date, product, planilha, sistema, sheet_totals)
      return [ nil, nil ] if status == :ok
      return [ :text, nil ] if status == :not_comparable

      other_units = @ordered.fetch([ customer, date, product ], []).reject { |line| line.unit == product.unit }
      return [ :other_unit, "Safra: #{other_units.map { |line| fmt(line.quantity, line.unit) }.join(' + ')}" ] if other_units.any?

      swapped = swapped_product(customer, date, product, status == :only_system ? sistema : planilha, status, sheet_totals)
      return [ :other_product, swapped ] if swapped
      return [ :not_in_sheet, nil ] if status == :only_system

      day = neighbor_days(date).find { |d| same?(ordered(customer, d, product), planilha) }
      return [ :other_day, "no Safra está em #{day.strftime('%d/%m')}" ] if day

      other = @ordered.keys.find { |c, d, p| d == date && p == product && c != customer && same?(ordered(c, d, p), planilha) }
      return [ :other_customer, "no Safra está em #{other.first.short_name}" ] if other

      [ :unexplained, nil ]
    end

    # Mesmo cliente, dia e quantidade, mas outro corte da mesma matéria-prima (chuchu em cubos × em cubinhos).
    def swapped_product(customer, date, product, quantity, status, sheet_totals)
      candidates = if status == :only_system
        sheet_totals.reject { |other, _| other == product || ordered(customer, date, other) }.map { |other, q| [ other, q ] }
      else
        @ordered.keys.filter_map { |c, d, other| [ other, ordered(c, d, other) ] if c == customer && d == date && other != product && !sheet_totals.key?(other) }
      end
      other, = candidates.find { |other, q| other.raw_material_id == product.raw_material_id && same?(q, quantity) }
      other && "#{status == :only_system ? 'na planilha' : 'no Safra'}: #{other.name}"
    end
  end
end
