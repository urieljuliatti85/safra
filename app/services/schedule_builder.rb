# Programação (R3.3, R3.4, D35): o que cada cliente pediu, por data de entrega, num período de quatro dias que pode
# atravessar de uma semana para outra. Cada item mantém a quantidade total e a marca de andamento do Gerente de
# Produção (quadrado: produzir no dia; ponto: já pronto). Lê as linhas do pedido, sem copiar a demanda.
class ScheduleBuilder
  PERIOD_DAYS = 4

  Entry = Data.define(:line_id, :product, :quantity, :unit, :delivery_date, :production_date, :note, :mark)
  Group = Data.define(:customer, :entries)

  # days: 1 para um dia de entrega (API e BI); PERIOD_DAYS na tela e no PDF.
  def initialize(company:, date:, days: 1)
    @company = company
    @dates = date..(date + days - 1)
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      lines = OrderLine.where(delivery_date: @dates).where("quantity > 0")
                       .includes({ order: :customer }, product: [ :cut, :production_rule, :raw_material ])
      lines.group_by { |l| l.order.customer }.sort_by { |customer, _| customer.name }.map do |customer, customer_lines|
        entries = customer_lines.sort_by { |l| [ l.delivery_date, Product::GROUPS.index(l.product.product_group), l.product.name, l.id ] }.map do |l|
          Entry.new(line_id: l.id, product: l.product, quantity: l.quantity, unit: l.unit, delivery_date: l.delivery_date, note: l.note,
                    production_date: l.product.raw? ? nil : l.product.production_date_for(l.delivery_date), mark: l.schedule_mark)
        end
        Group.new(customer: customer, entries: entries)
      end
    end
  end
end
