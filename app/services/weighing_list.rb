# Checklist de pesagem de um dia de entrega (R2.6, R2.7; esteira simplificada, passo 5): por cliente, os produtos com a
# quantidade e a unidade do pedido e o peso real em kg. A soma em kg só sai quando todos os itens do cliente foram
# pesados (R2.6: "a soma em kg só pode ser feita depois de registrados os pesos reais").
class WeighingList
  Stop = Data.define(:customer, :lines) do
    def weighed = lines.count { |line| line.actual_kg }
    def complete? = weighed == lines.size
    def kg_total = (lines.sum(&:actual_kg) if complete?)
  end

  def initialize(company:, date:)
    @company = company
    @date = date
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      lines = OrderLine.where(delivery_date: @date).where("quantity > 0").includes(:product, order: :customer)
      lines.group_by(&:customer).sort_by { |customer, _| customer.name }.map do |customer, customer_lines|
        Stop.new(customer: customer, lines: customer_lines.sort_by { |line| line.product.name })
      end
    end
  end
end
