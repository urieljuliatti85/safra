# Grava o peso real em kg da pesagem de um dia de entrega (R2.6, R2.7): { order_line_id => texto em kg }.
# Texto vazio apaga o peso (ainda não pesado); 0 é pesado e nada saiu. A quantidade e a unidade do pedido não mudam.
# Só entram linhas da data de entrega aberta. Qualquer erro desfaz tudo.
class WeighingSaver
  Result = Data.define(:errors, :changed) do
    def ok? = errors.empty?
  end

  def initialize(date:, weights:)
    @date = date
    @weights = weights
  end

  def call
    errors = []
    changed = 0
    OrderLine.transaction do
      OrderLine.where(id: @weights.keys, delivery_date: @date).includes(:product, order: :customer).find_each do |line|
        line.actual_kg = @weights[line.id.to_s].to_s.strip.presence
        next unless line.changed?

        if line.save
          changed += 1
        else
          errors << "#{line.product.name} (#{line.order.customer.short_name}): #{line.errors.full_messages.to_sentence}"
        end
      end
      raise ActiveRecord::Rollback if errors.any?
    end
    Result.new(errors: errors, changed: errors.any? ? 0 : changed)
  end
end
