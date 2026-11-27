# Versões enviadas da Planilha de Produção e das Compras que trazem itens de um cliente em certos dias de entrega.
# Desfazer uma importação e apagar o pedido da semana apagam essas versões junto: tiram do processo o que o pedido gerou.
module SentPlans
  module_function

  # dates: dias de entrega em texto ("2026-10-13"); since: só as enviadas a partir dessa hora (nil = todas).
  def with_items(customer:, dates:, since: nil)
    dates = dates.to_set
    return [] if dates.empty?

    production = scoped(ProductionPlan, since).select do |plan|
      plan.items.any? { |item| Array(item.breakdown).any? { |b| b["customer_code"] == customer.code && dates.include?(b["delivery_date"]) } }
    end
    purchase = scoped(PurchasePlan, since).select do |plan|
      plan.items.any? { |item| Array(item.breakdown).any? { |b| b["customer"] == customer.short_name && dates.include?(b["delivery_date"]) } }
    end
    (production + purchase).sort_by { |plan| [ plan.date, plan.class.name, plan.version ] }
  end

  def scoped(model, since)
    plans = model.where.not(sent_at: nil).includes(:items)
    since ? plans.where(sent_at: since..) : plans
  end
end
