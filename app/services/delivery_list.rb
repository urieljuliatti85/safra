# Entregas de um dia, uma parada por cliente: endereço, janela de recebimento e o que vai no caminhão.
# Base para logística e roteirização (API /deliveries). Peso só soma o que é pedido em kg; as outras unidades
# vêm somadas por unidade, para nunca misturar kg com caixa ou unidade.
class DeliveryList
  Line = Data.define(:product, :quantity, :unit, :note)
  Stop = Data.define(:customer, :lines) do
    def kg_total = lines.select { |line| line.unit == "kg" }.sum(&:quantity)

    def other_units
      lines.reject { |line| line.unit == "kg" }.group_by(&:unit).transform_values { |group| group.sum(&:quantity) }
    end
  end

  def initialize(company:, date:)
    @company = company
    @date = date
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      lines = OrderLine.where(delivery_date: @date).where("quantity > 0").includes(:product, order: :customer)
      lines.group_by { |line| line.order.customer }.sort_by { |customer, _| customer.name }.map do |customer, customer_lines|
        Stop.new(customer: customer, lines: customer_lines.sort_by { |line| line.product.name }.map do |line|
          Line.new(product: line.product, quantity: line.quantity, unit: line.unit, note: line.note)
        end)
      end
    end
  end
end
