# Painel inicial: em que etapa está o trabalho do dia (pedidos, programação, produção, compras).
# Só lê o que as telas já calculam (ProductionPlanner, PurchasePlanner, PlanDiff, ConferenceChecker);
# não guarda nem calcula nada à parte.
class DashboardSummary
  # state: :ok (em ordem), :pending (falta fazer), :changed (mudou depois do envio), :idle (nada a fazer)
  Stage = Data.define(:key, :title, :state, :status, :facts, :action_label, :action_path, :secondary)
  Result = Data.define(:date, :stages, :week, :alerts, :stale_production, :stale_purchase)

  def initialize(company:, date: Date.current)
    @company = company
    @date = date
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      purchase_result = PurchasePlanner.new(company: @company).call
      stages = [ orders_stage, schedule_stage, production_stage, purchase_stage(purchase_result) ]
      Result.new(date: @date, stages: stages, week: WeekOverview.new(company: @company, date: @date).call,
                 alerts: ConferenceChecker.new(company: @company).call.count { |alert| alert.level == :warn },
                 stale_production: StalePlans.dates(@company), stale_purchase: stale_purchase_dates(purchase_result))
    end
  end

  private

  def orders_stage
    week_start = @date.beginning_of_week
    total = Customer.count
    with_orders = OrderLine.joins(:order).where(orders: { week_start: week_start }).where("quantity > 0").distinct.count("orders.customer_id")
    missing = total - with_orders
    state = total.zero? || missing.positive? ? :pending : :ok
    status = if total.zero? then "Sem clientes cadastrados"
    elsif missing.positive? then "#{missing == 1 ? 'Falta 1 cliente' : "Faltam #{missing} clientes"} na semana"
    else "Todos os clientes lançados"
    end
    Stage.new(key: :orders, title: "Pedidos", state: state, status: status,
              facts: [ "#{with_orders} de #{total} clientes com pedido na semana de #{Formatting.short_date(week_start)}" ],
              action_label: "Lançar pedidos", action_path: Rails.application.routes.url_helpers.orders_path, secondary: nil)
  end

  def schedule_stage
    today = deliveries(@date)
    tomorrow = deliveries(@date + 1)
    state = today[:items].zero? && tomorrow[:items].zero? ? :idle : :ok
    status = today[:items].zero? ? "Sem entregas hoje" : "#{plural(today[:customers], 'cliente recebe', 'clientes recebem')} hoje"
    Stage.new(key: :schedule, title: "Programação", state: state, status: status,
              facts: [ "Hoje: #{plural(today[:items], 'item', 'itens')}", "Amanhã: #{plural(tomorrow[:items], 'item', 'itens')} para #{plural(tomorrow[:customers], 'cliente', 'clientes')}" ],
              action_label: "Ver programação", action_path: Rails.application.routes.url_helpers.schedule_path(date: @date), secondary: nil)
  end

  def production_stage
    result = ProductionPlanner.new(company: @company, date: @date).call
    sent = ProductionPlan.where(date: @date).where.not(sent_at: nil).order(:version).last
    changes = sent ? PlanDiff.production(sent, result) : []
    state, status = plan_state(result.items.any?, sent, changes, "Sem produção hoje", "Falta enviar aos setores")
    facts = result.items.any? ? [ "#{plural(result.items.size, 'item', 'itens')} em #{plural(result.items.map { |item| item.product.sector }.uniq.size, 'setor', 'setores')}" ] : []
    facts << "Mudou: #{plural(changes.size, 'item', 'itens')} diferente#{'s' unless changes.size == 1} da versão enviada" if changes.any?
    Stage.new(key: :production, title: "Produção", state: state, status: status, facts: facts,
              action_label: state == :pending ? "Revisar e enviar" : "Abrir produção",
              action_path: Rails.application.routes.url_helpers.production_path(date: @date), secondary: nil)
  end

  def purchase_stage(result)
    date = PurchaseDay.where(date: @date..).order(:date).pick(:date)
    helpers = Rails.application.routes.url_helpers
    return Stage.new(key: :purchase, title: "Compras", state: :idle, status: "Sem dia de compra cadastrado",
                     facts: [ "Cadastre os dias da CEASA em Regras" ], action_label: "Abrir Regras",
                     action_path: helpers.rules_path(anchor: "compras"), secondary: nil) unless date

    needs = result.purchases.fetch(date, [])
    sent = PurchasePlan.where(date: date).where.not(sent_at: nil).order(:version).last
    changes = sent ? PlanDiff.purchase(sent, needs) : []
    state, status = plan_state(needs.any?, sent, changes, "Nada a comprar", "Falta enviar aos fornecedores")
    counted = StockCount.where(date: @date).pluck(:raw_material_id)
    uncounted = needs.select { |need| need.unit == "kg" && !counted.include?(need.raw_material.id) }.size
    facts = [ "Próxima compra: #{Formatting.weekday_date(date)}" ]
    facts << "#{plural(needs.size, 'matéria-prima', 'matérias-primas')} a comprar" if needs.any?
    facts << "#{uncounted} sem contagem de estoque hoje" if uncounted.positive?
    facts << "Mudou: #{plural(changes.size, 'item', 'itens')} diferente#{'s' unless changes.size == 1} da versão enviada" if changes.any?
    Stage.new(key: :purchase, title: "Compras", state: state, status: status, facts: facts,
              action_label: "Abrir compra", action_path: helpers.purchases_path(date: date),
              secondary: uncounted.positive? ? { label: "Contar estoque", path: helpers.stock_path(date: @date) } : nil)
  end

  def plan_state(any_items, sent, changes, idle_text, unsent_text)
    return [ :idle, idle_text ] if !any_items && sent.nil?
    return [ :pending, unsent_text ] if sent.nil?
    return [ :changed, "Mudou desde a versão #{sent.version} enviada" ] if changes.any?

    [ :ok, "Enviada, versão #{sent.version}" ]
  end

  def deliveries(date)
    lines = OrderLine.where(delivery_date: date).where("quantity > 0").joins(:order)
    { items: lines.count, customers: lines.distinct.count("orders.customer_id") }
  end

  def stale_purchase_dates(result)
    PurchasePlan.where.not(sent_at: nil).distinct.pluck(:date).sort.select do |date|
      latest = PurchasePlan.where(date: date).where.not(sent_at: nil).order(:version).last
      PlanDiff.purchase(latest, result.purchases.fetch(date, [])).any?
    end
  end

  def plural(count, singular, plural_form)
    "#{count} #{count == 1 ? singular : plural_form}"
  end
end
