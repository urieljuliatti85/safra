# Conferência de quantidades, unidades e datas. Gera alertas (nunca erros) a partir dos pedidos.
# Referência: função alertas() do protótipo (docs/prototipo/safra.html, privado).
class ConferenceChecker
  # level: :warn | :mute. action: para onde ir corrigir (nil quando não há um lugar certo).
  Action = Data.define(:label, :path)
  Alert = Data.define(:level, :kind, :message, :action)

  FACTOR_NOTE = /1,3|copiad|50 ou 25/

  # Quantidade fora do comum: ao menos OUTLIER_RATIO vezes a mediana do mesmo cliente, produto e unidade, com histórico
  # de OUTLIER_MIN_HISTORY pedidos e OUTLIER_MIN_GAP acima da mediana (1 contra 8 kg não é erro de digitação).
  # Se o cliente já pediu ao menos a metade disso antes, é padrão (segunda e domingo maiores), não erro.
  # Só para cima: pedido pequeno costuma ser de propósito (dia de entrega menor).
  OUTLIER_RATIO = 5
  OUTLIER_MIN_HISTORY = 3
  OUTLIER_MIN_GAP = 10

  # week: segunda-feira da semana a conferir (pela data de entrega das linhas); nil confere todas as semanas.
  # purchase_result: o PurchasePlanner já calculado por quem chama (o Painel), para não refazer a compra inteira.
  def initialize(company:, week: nil, purchase_result: nil)
    @company = company
    @week = week
    @purchase_result = purchase_result
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      lines = OrderLine.where("quantity > 0")
      lines = lines.where(delivery_date: week_range) if @week
      lines = lines.includes({ order: :customer }, product: [ :cut, { raw_material: :supplier } ])
      alerts = line_note_alerts(lines) + missing_factor_alerts(lines) + unit_alerts(lines) +
               supplier_alerts(lines) + factor_note_alerts(lines) + uncovered_alerts + sunday_alerts(lines) +
               outlier_alerts(lines) + deadline_alerts
      alerts.sort_by { |a| [ a.level == :warn ? 0 : 1, a.kind, a.message ] }
    end
  end

  private

  # Uma linha por cliente, produto e observação, com todas as datas afetadas.
  def line_note_alerts(lines)
    lines.select { |l| l.note.present? }.group_by { |l| [ l.order.customer, l.product, l.note ] }.map do |(customer, product, note), group|
      dates = group.map(&:delivery_date).uniq.sort.map { |d| Formatting.short_date(d) }.join(", ")
      alert(:warn, "Pedido", "#{customer.short_name}: #{product.name} (#{dates}). #{note}.", action: order_action(group.min_by(&:delivery_date)))
    end
  end

  def missing_factor_alerts(lines)
    lines.reject { |l| l.product.raw? || l.product.raw_material.multiply_factor }
         .group_by { |l| l.product.raw_material }.map do |raw_material, group|
      names = group.map { |l| l.product.name }.uniq.sort.join(", ")
      alert(:warn, "Sem fator", "#{raw_material.name}: sem fator de conversão, então a compra não é calculada (#{names}).",
                action: raw_material_action("Completar o fator", raw_material))
    end
  end

  def unit_alerts(lines)
    lines.group_by { |l| [ l.product.raw_material, l.product.product_group ] }.filter_map do |(raw_material, _), group|
      by_unit = group.group_by(&:unit)
      next if by_unit.size < 2

      # Vai ao pedido mais antigo na unidade menos usada: é a que costuma estar fora do padrão.
      odd_unit = by_unit.min_by { |unit, lines| [ lines.size, unit ] }.last
      alert(:warn, "Unidade", "#{raw_material.name}: pedido em unidades diferentes (#{by_unit.keys.sort.join(' e ')}). Não dá para somar sem converter.",
                action: order_action(odd_unit.min_by(&:delivery_date)))
    end
  end

  def supplier_alerts(lines)
    names = lines.map { |l| l.product.raw_material }.uniq.select { |rm| rm.supplier.nil? }.map(&:name).sort
    return [] if names.empty?

    [ alert(:mute, "Fornecedor", "Sem fornecedor cadastrado: #{names.join(', ')}.",
                action: Action.new("Ver matérias-primas sem fornecedor", routes.raw_materials_path(filter: "no_supplier"))) ]
  end

  def factor_note_alerts(lines)
    lines.map { |l| l.product.raw_material }.uniq.select { |rm| rm.note.to_s.match?(FACTOR_NOTE) }.map do |rm|
      alert(:mute, "Fator", "#{rm.name}: #{rm.note}.", action: raw_material_action("Revisar o fator", rm))
    end
  end

  # Linhas cuja produção cai antes da primeira compra cadastrada: não entram em nenhuma compra.
  def uncovered_alerts
    uncovered = (@purchase_result || PurchasePlanner.new(company: @company).call).uncovered
    uncovered = uncovered.select { |line| week_range.cover?(line.delivery_date) } if @week
    return [] if uncovered.empty?

    dates = uncovered.map(&:delivery_date).uniq.sort.map { |d| Formatting.short_date(d) }.join(", ")
    [ alert(:mute, "Compra", "#{uncovered.size} linhas de pedido (entregas em #{dates}) são produzidas antes da primeira compra cadastrada e não entram em nenhuma compra.",
                action: Action.new("Cadastrar dia de compra", routes.rules_path(anchor: "compras"))) ]
  end

  def sunday_alerts(lines)
    sundays = lines.select { |l| l.delivery_date.sunday? }
    return [] if sundays.empty?

    [ alert(:mute, "Data", "#{sundays.size} linhas com entrega no domingo. Domingo não tem produção: ela cai para sábado.",
                action: order_action(sundays.min_by(&:delivery_date))) ]
  end

  # Compara com todos os pedidos do cliente (de qualquer semana), sem contar a própria linha.
  def outlier_alerts(lines)
    history = OrderLine.where("quantity > 0").where(product_id: lines.map(&:product_id).uniq).joins(:order)
                       .pluck("orders.customer_id", :product_id, :unit, :id, :quantity)
                       .group_by { |customer_id, product_id, unit, _, _| [ customer_id, product_id, unit ] }
    lines.filter_map do |line|
      others = history.fetch([ line.order.customer_id, line.product_id, line.unit ], []).reject { |row| row[3] == line.id }.map(&:last)
      next if others.size < OUTLIER_MIN_HISTORY

      median = others.sort[others.size / 2]
      next unless line.quantity >= median * OUTLIER_RATIO && line.quantity - median >= OUTLIER_MIN_GAP
      next if others.max * 2 >= line.quantity

      alert(:warn, "Quantidade", "#{line.order.customer.short_name}: #{line.product.name} com #{Formatting.qty(line.quantity)} #{line.unit} " \
                                 "em #{Formatting.short_date(line.delivery_date)}, quando o normal é #{Formatting.qty(median)} #{line.unit}. Confira se não é erro de digitação.",
            action: order_action(line))
    end
  end

  def week_range = @week..(@week + 6)

  def alert(level, kind, message, action: nil)
    Alert.new(level: level, kind: kind, message: message, action: action)
  end

  def routes = Rails.application.routes.url_helpers

  def raw_material_action(label, raw_material)
    Action.new(label, routes.raw_materials_path(q: raw_material.name))
  end

  # Abre a semana do pedido onde o problema aparece (a linha mais antiga).
  # Pedido semanal recebido depois das 15h da quinta anterior (R1.4, D7). Só avisa: nada é bloqueado.
  def deadline_alerts
    orders = Order.where.not(received_at: nil).includes(:customer)
    orders = orders.where(week_start: @week) if @week
    orders.select(&:late?).map do |order|
      received = order.received_at
      alert(:warn, "Prazo", "#{order.customer.short_name}: pedido da semana de #{Formatting.short_date(order.week_start)} recebido em " \
                            "#{Formatting.weekday_date(received.to_date)} às #{received.strftime('%H:%M')}, depois do prazo " \
                            "(#{Formatting.weekday_date(order.deadline.to_date)}, 15h).", action: order_link(order))
    end
  end

  def order_action(line) = order_link(line.order)

  def order_link(order)
    Action.new("Abrir pedido de #{order.customer.short_name}", routes.orders_path(customer: order.customer.code, week: order.week_start.iso8601))
  end
end
