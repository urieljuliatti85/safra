# Programação de um dia de entrega: o que cada cliente pediu e quando cada item é produzido.
class ScheduleBuilder
  Entry = Data.define(:product, :quantity, :unit, :production_date, :note)
  Group = Data.define(:customer, :entries)

  def initialize(company:, date:)
    @company = company
    @date = date
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      lines = OrderLine.where(delivery_date: @date).where("quantity > 0")
                       .includes(:order, product: [ :cut, :production_rule ])
      lines.group_by { |l| l.order.customer }.sort_by { |customer, _| customer.name }.map do |customer, customer_lines|
        entries = customer_lines.sort_by { |l| [ Product::GROUPS.index(l.product.product_group), l.product.name ] }.map do |l|
          Entry.new(product: l.product, quantity: l.quantity, unit: l.unit, note: l.note,
                    production_date: l.product.raw? ? nil : l.product.production_date_for(@date))
        end
        Group.new(customer: customer, entries: entries)
      end
    end
  end
end
