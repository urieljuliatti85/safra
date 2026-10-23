# Planos enviados não mudam sozinhos: avisa em quais dias o pedido atual já difere da versão enviada.
module StalePlans
  module_function

  def dates(company)
    ActsAsTenant.with_tenant(company) do
      ProductionPlan.where.not(sent_at: nil).distinct.pluck(:date).sort.select do |date|
        latest = ProductionPlan.latest_sent(date)
        PlanDiff.production(latest, ProductionPlanner.new(company: company, date: date).call).any?
      end
    end
  end

  # Mesmo para as compras enviadas. Recebe o resultado do PurchasePlanner quando quem chama já calculou.
  def purchase_dates(company, result = nil)
    ActsAsTenant.with_tenant(company) do
      result ||= PurchasePlanner.new(company: company).call
      PurchasePlan.where.not(sent_at: nil).distinct.pluck(:date).sort.select do |date|
        latest = PurchasePlan.where(date: date).where.not(sent_at: nil).order(:version).last
        PlanDiff.purchase(latest, result.purchases.fetch(date, [])).any?
      end
    end
  end

  def warning(company)
    stale = dates(company)
    return nil if stale.empty?

    "Atenção: a produção de #{stale.map { |d| Formatting.short_date(d) }.join(', ')} mudou desde a versão enviada aos setores."
  end
end
