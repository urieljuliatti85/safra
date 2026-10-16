# Formato JSON da API v1. Datas em ISO 8601 (AAAA-MM-DD); quantidades como número decimal (kg, un, cx ou mç).
module ApiPresenter
  module_function

  def number(value) = value&.to_f

  def customer(customer) = { code: customer.code, name: customer.name, short_name: customer.short_name }

  def address(customer)
    { line: customer.address, district: customer.district, city: customer.city, state: customer.state,
      postal_code: customer.postal_code, full: customer.full_address,
      latitude: number(customer.latitude), longitude: number(customer.longitude) }
  end

  def delivery_window(customer)
    { from: customer.delivery_from&.strftime("%H:%M"), until: customer.delivery_until&.strftime("%H:%M") }
  end

  # Cliente com o endereço de entrega (catálogo e entregas).
  def customer_with_address(customer)
    customer(customer).merge(address: address(customer), delivery_window: delivery_window(customer), delivery_notes: customer.delivery_notes)
  end

  def deliveries(date, stops)
    { date: date.iso8601,
      missing_address: stops.reject { |stop| stop.customer.address_complete? }.map { |stop| stop.customer.code },
      stops: stops.map do |stop|
        customer_with_address(stop.customer).merge(
          kg_total: number(stop.kg_total), other_units: stop.other_units.map { |unit, quantity| { unit: unit, quantity: number(quantity) } },
          lines: stop.lines.map { |line| { product: line.product.code, name: line.product.name, quantity: number(line.quantity), unit: line.unit, note: line.note } }
        )
      end }
  end

  def supplier(supplier) = { id: supplier.id, name: supplier.name }

  def cut(cut) = { code: cut.code, name: cut.name, sector: cut.sector, sector_name: cut.sector_name, lead_days: cut.lead_days }

  def raw_material(raw_material)
    { code: raw_material.code, name: raw_material.name, supplier: raw_material.supplier&.name,
      multiply_factor: number(raw_material.multiply_factor), kg_per_package: number(raw_material.kg_per_package),
      kg_per_peeled_box: number(raw_material.kg_per_peeled_box), purchase_package: raw_material.purchase_package }
  end

  def product(product)
    { code: product.code, name: product.name, group: product.product_group, unit: product.unit,
      raw_material: product.raw_material.code, cut: product.cut&.code, sector: product.sector }
  end

  def order(order, changed_dates: nil)
    lines = order.lines.includes(:product).sort_by { |line| [ line.delivery_date, line.product.name, line.unit ] }
    body = { customer: order.customer.code, week_start: order.week_start.iso8601,
             lines: lines.map { |line| order_line(line) } }
    body[:changed_dates] = changed_dates.map(&:iso8601) if changed_dates
    body
  end

  def order_line(line)
    { product: line.product.code, unit: line.unit, date: line.delivery_date.iso8601, quantity: number(line.quantity), note: line.note }
  end

  def schedule(date, groups)
    { date: date.iso8601,
      customers: groups.map do |group|
        { customer: customer(group.customer),
          items: group.entries.map do |entry|
            { product: entry.product.code, name: entry.product.name, quantity: number(entry.quantity), unit: entry.unit,
              production_date: entry.production_date&.iso8601, note: entry.note }
          end }
      end }
  end

  def plan_version(plan) = plan && { version: plan.version, sent_at: plan.sent_at.iso8601 }

  def change(change) = { label: change.label, unit: change.unit, before: number(change.before), after: number(change.after), kind: change.kind.to_s }

  def production(result, sent, changes)
    { date: result.date.iso8601, sent_version: plan_version(sent), changes_since_sent: changes.map { |c| change(c) },
      items: result.items.map do |item|
        { product: item.product.code, name: item.product.name, sector: item.product.sector, quantity: number(item.quantity), unit: item.unit,
          breakdown: item.breakdown.map { |b| { customer: b.customer.code, delivery_date: b.delivery_date.iso8601, quantity: number(b.quantity) } } }
      end,
      aprontes: result.aprontes.map { |a| { raw_material: a.raw_material.code, kg: number(a.kg), boxes: a.boxes } } }
  end

  def purchase(date, needs, sent, changes)
    { date: date&.iso8601, sent_version: plan_version(sent), changes_since_sent: changes.map { |c| change(c) },
      items: needs.map do |need|
        { raw_material: need.raw_material.code, name: need.raw_material.name, supplier: need.raw_material.supplier&.name, unit: need.unit,
          kg: number(need.kg), stock_kg: number(need.stock_kg), net_kg: number(need.net_kg), packages: need.packages,
          package: need.raw_material.purchase_package, missing_factor: need.missing_factor }
      end }
  end

  def stock(date, counts, previous)
    { date: date.iso8601,
      counts: counts.map { |count| { raw_material: count.raw_material.code, kg: number(count.kg) } },
      previous: previous.map { |count| { raw_material: count.raw_material.code, kg: number(count.kg), date: count.date.iso8601 } } }
  end
end
