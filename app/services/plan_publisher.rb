# Salva o plano calculado como uma nova versão ("enviar aos setores").
# Versões enviadas ficam congeladas: alterações de pedido depois disso aparecem como diferença (PlanDiff).
class PlanPublisher
  def self.production(company:, result:)
    ActsAsTenant.with_tenant(company) do
      ProductionPlan.transaction do
        plan = ProductionPlan.create!(date: result.date, version: next_version(ProductionPlan, result.date), sent_at: Time.current)
        result.items.each do |item|
          plan.items.create!(
            product: item.product, quantity: item.quantity, unit: item.unit,
            breakdown: item.breakdown.map do |b|
              { customer: b.customer.short_name, customer_code: b.customer.code, delivery_date: b.delivery_date.iso8601, quantity: b.quantity.to_f }
            end
          )
        end
        plan
      end
    end
  end

  def self.purchase(company:, date:, needs:)
    ActsAsTenant.with_tenant(company) do
      PurchasePlan.transaction do
        plan = PurchasePlan.create!(date: date, version: next_version(PurchasePlan, date), sent_at: Time.current)
        needs.each do |need|
          plan.items.create!(
            raw_material: need.raw_material, unit: need.unit, kg: need.net_kg, packages: need.packages,
            breakdown: need.breakdown.map do |b|
              { customer: b.customer.short_name, product: b.product.name, delivery_date: b.delivery_date.iso8601, quantity: b.quantity.to_f, unit: b.unit }
            end
          )
        end
        plan
      end
    end
  end

  def self.next_version(model, date)
    model.where(date: date).maximum(:version).to_i + 1
  end
  private_class_method :next_version
end
