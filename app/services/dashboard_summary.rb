# Painel inicial: em que etapa está o trabalho do dia (pedidos, programação, produção, compras).
# Só lê o que as telas já calculam (ProductionPlanner, PurchasePlanner, PlanDiff, ConferenceChecker);
# não guarda nem calcula nada à parte.
class DashboardSummary
  # state: :ok (em ordem), :pending (falta fazer), :changed (mudou depois do envio), :idle (nada a fazer)
  Stage = Data.define(:key, :title, :state, :status, :facts, :action_label, :action_path, :secondary)
  Result = Data.define(:date, :stages, :alerts, :stale_production, :stale_purchase)

  def initialize(company:, date: Date.current)
    @company = company
    @date = date
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      purchase_result = PurchasePlanner.new(company: @company).call
      alerts = ConferenceChecker.new(company: @company, week: @date.beginning_of_week).call.select { |alert| alert.level == :warn }
      stages = [ orders_stage(alerts), schedule_stage, production_stage, purchase_stage(purchase_result) ]
      Result.new(date: @date, stages: stages, alerts: alerts.size,
                 stale_production: StalePlans.dates(@company), stale_purchase: StalePlans.purchase_dates(@company, purchase_result))
    end
  end

  private

  # Tipos de alerta de atenção, do mais grave para o menos, com o texto que aparece no Painel.
  ALERT_KINDS = {
    "Sem fator" => [ "matéria-prima sem fator", "matérias-primas sem fator" ],
    "Unidade" => [ "matéria-prima com unidades misturadas", "matérias-primas com unidades misturadas" ],
    "Pedido" => [ "observação em pedido", "observações em pedidos" ]
  }.freeze

  # "2 matérias-primas sem fator, 1 observação em pedido": o que pesa nos alertas, sem abrir a Conferência.
  def alert_breakdown(alerts)
    counts = alerts.group_by(&:kind).transform_values(&:size)
    ALERT_KINDS.filter_map { |kind, (one, many)| plural(counts[kind], one, many) if counts[kind] }.join(", ")
  end

  # Os alertas da conferência são sobre os pedidos: ficam na própria etapa, como segundo caminho.
  def orders_stage(alerts)
    week_start = @date.beginning_of_week
    total = Customer.count
    launched_ids = OrderLine.joins(:order).where(orders: { week_start: week_start }).where("quantity > 0").distinct.pluck("orders.customer_id")
    with_orders = launched_ids.size
    missing = total - with_orders
    state = total.zero? || missing.positive? ? :pending : :ok
    status = if total.zero? then "Sem clientes cadastrados"
    elsif missing.positive? then "#{missing == 1 ? 'Falta 1 cliente' : "Faltam #{missing} clientes"} na semana"
    else "Todos os clientes lançados"
    end
    helpers = Rails.application.routes.url_helpers
    return Stage.new(key: :orders, title: "Pedidos", state: state, status: status, facts: [ "Cadastre os clientes antes de lançar pedidos" ],
                     action_label: "Cadastrar clientes", action_path: helpers.customers_path, secondary: nil) if total.zero?

    facts = [ "Semana de #{Formatting.short_date(week_start)}: #{with_orders} de #{total} clientes lançados" ]
    facts << "Falta: #{missing_names(launched_ids)}" if missing.positive?
    facts << "Alertas: #{alert_breakdown(alerts)}" if alerts.any?
    Stage.new(key: :orders, title: "Pedidos", state: state, status: status, facts: facts,
              action_label: "Lançar pedidos", action_path: helpers.orders_path,
              secondary: alerts.any? ? { label: "#{plural(alerts.size, 'alerta', 'alertas')} para conferir", path: helpers.conference_path(week: week_start.iso8601), attention: true } : nil)
  end

  def schedule_stage
    today = deliveries(@date)
    tomorrow = deliveries(@date + 1)
    state = today[:items].zero? && tomorrow[:items].zero? ? :idle : :ok
    status = today[:items].zero? ? "Sem entregas hoje" : "#{plural(today[:customers], 'cliente recebe', 'clientes recebem')} hoje"
    Stage.new(key: :schedule, title: "Programação", state: state, status: status,
              facts: [ "#{plural(today[:items], 'item', 'itens')} para entregar hoje", "Amanhã: #{plural(tomorrow[:items], 'item', 'itens')} para #{plural(tomorrow[:customers], 'cliente', 'clientes')}" ],
              action_label: "Ver programação", action_path: Rails.application.routes.url_helpers.schedule_path(date: @date), secondary: nil)
  end

  def production_stage
    result = ProductionPlanner.new(company: @company, date: @date).call
    sent = ProductionPlan.where(date: @date).where.not(sent_at: nil).order(:version).last
    changes = sent ? PlanDiff.production(sent, result) : []
    state, status = plan_state(result.items.any?, sent, changes, "Sem produção hoje", "Falta enviar aos setores")
    facts = result.items.any? ? [ "#{plural(result.items.size, 'item', 'itens')} em #{plural(result.items.map { |item| item.product.sector }.uniq.size, 'setor', 'setores')}" ] : []
    facts << "Os setores estão com a versão #{sent.version}; reenvie" if changes.any?
    Stage.new(key: :production, title: "Produção", state: state, status: status, facts: facts,
              action_label: action_label(state, "Abrir produção"),
              action_path: Rails.application.routes.url_helpers.production_path(date: @date), secondary: nil)
  end

  def purchase_stage(result)
    date = PurchaseDay.where(date: @date..).order(:date).pick(:date)
    helpers = Rails.application.routes.url_helpers
    return Stage.new(key: :purchase, title: "Compras", state: :idle, status: "Sem dia de compra cadastrado",
                     facts: [ "Sem os dias da CEASA, a compra não é calculada" ], action_label: "Cadastrar dias de compra",
                     action_path: helpers.rules_path(anchor: "compras"), secondary: nil) unless date

    needs = result.purchases.fetch(date, [])
    sent = PurchasePlan.where(date: date).where.not(sent_at: nil).order(:version).last
    changes = sent ? PlanDiff.purchase(sent, needs) : []
    state, status = plan_state(needs.any?, sent, changes, "Nada a comprar", "Falta enviar aos fornecedores")
    counted = StockCount.where(date: @date).pluck(:raw_material_id)
    uncounted = needs.select { |need| need.unit == "kg" && !counted.include?(need.raw_material.id) }.size
    facts = [ "Próxima compra: #{Formatting.weekday_date(date)}" ]
    facts << "#{plural(needs.size, 'matéria-prima', 'matérias-primas')} a comprar" if needs.any?
    facts << "Estoque de hoje sem contagem: #{plural(uncounted, 'matéria-prima', 'matérias-primas')}" if uncounted.positive?
    facts << "Os fornecedores estão com a versão #{sent.version}; reenvie" if changes.any?
    Stage.new(key: :purchase, title: "Compras", state: state, status: status, facts: facts,
              action_label: action_label(state, "Abrir compra"), action_path: helpers.purchases_path(date: date),
              secondary: uncounted.positive? ? { label: "Contar estoque", path: helpers.stock_path(date: @date) } : nil)
  end

  def plan_state(any_items, sent, changes, idle_text, unsent_text)
    return [ :idle, idle_text ] if !any_items && sent.nil?
    return [ :pending, unsent_text ] if sent.nil?
    return [ :changed, "#{plural(changes.size, 'item mudou', 'itens mudaram')} depois do envio" ] if changes.any?

    [ :ok, "Enviada, versão #{sent.version}" ]
  end

  # A ação diz o que fazer: enviar o que falta, reenviar o que mudou, ou só abrir.
  def action_label(state, open_label)
    { pending: "Revisar e enviar", changed: "Ver diferença e reenviar" }.fetch(state, open_label)
  end

  # "Aurora Hotel e Bom Pastor"; mais de três vira "A, B, C e mais 2".
  def missing_names(launched_ids)
    names = Customer.where.not(id: launched_ids).order(:short_name).pluck(:short_name)
    shown = names.first(3)
    shown << "mais #{names.size - 3}" if names.size > 3
    shown.to_sentence
  end

  def deliveries(date)
    lines = OrderLine.where(delivery_date: date).where("quantity > 0").joins(:order)
    { items: lines.count, customers: lines.distinct.count("orders.customer_id") }
  end

  def plural(count, singular, plural_form)
    "#{count} #{count == 1 ? singular : plural_form}"
  end
end
