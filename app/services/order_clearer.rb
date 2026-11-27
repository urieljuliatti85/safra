# "Apagar pedido": tira do pedido de um cliente todas as linhas da semana, ou só as de um dia de entrega, digitadas ou
# importadas, e o que elas geraram:
# - Programação, Planilha de Produção, Compras e Pesagem são calculadas do pedido e voltam sozinhas (o dia de
#   execução, a marca e o peso ficam na linha e saem com ela);
# - as versões enviadas da Planilha de Produção e das Compras com itens dele são apagadas (SentPlans);
# - a planilha importada que não tem mais nada no pedido volta a pendente, e os apelidos que ela criou saem (os que ela
#   trocou voltam ao produto anterior). Apagando a semana, isso vale para todas as planilhas dela.
# O Estoque não muda: a contagem de produto pronto é digitada e vale para todos os clientes. O PDF de AFs pode cobrir
# várias semanas e fica aplicado. Fica uma versão "Pedido apagado" no histórico. Não pede a confirmação das 48 h: é
# correção de lançamento (cliente, semana ou dia errado), como desfazer (D8).
class OrderClearer
  Result = Data.define(:errors, :removed_lines, :removed_plans, :reopened_imports) do
    def ok? = errors.empty?
  end

  # date: um dia de entrega da semana; nil apaga a semana inteira.
  def initialize(order:, date: nil)
    @order = order
    @date = date
  end

  def call
    result = nil
    Order.transaction do
      @order.lock!
      lines = target_lines
      if lines.empty?
        result = failure(@date ? "O pedido de #{Formatting.short_date(@date)} já está vazio." : "O pedido desta semana já está vazio.")
        next
      end

      plans = SentPlans.with_items(customer: @order.customer, dates: lines.map { |line| line.delivery_date.iso8601 })
      saved = OrderGridSaver.new(order: @order, quantities: empty_grid(lines), source: "clear").call
      unless saved.ok?
        result = failure(*saved.errors)
        raise ActiveRecord::Rollback
      end

      plans.each(&:destroy!)
      result = Result.new(errors: [], removed_lines: lines.size, removed_plans: plans, reopened_imports: release_imports)
    end
    result
  end

  private

  def failure(*errors) = Result.new(errors: errors, removed_lines: 0, removed_plans: [], reopened_imports: [])

  def target_lines
    lines = @order.lines.where("quantity > 0")
    lines = lines.where(delivery_date: @date) if @date
    lines.to_a
  end

  def empty_grid(lines)
    lines.each_with_object({}) do |line, grid|
      (grid["#{line.product_id}|#{line.unit}"] ||= {})[line.delivery_date.iso8601] = ""
    end
  end

  # Planilhas aplicadas nesta semana que não têm mais nenhuma quantidade no pedido: voltam a pendentes, sem o retrato do
  # desfazer, e os apelidos que criaram saem.
  def release_imports
    current = @order.lines.group(:product_id, :unit, :delivery_date).sum(:quantity)
    OrderImport.where(customer: @order.customer, week_start: @order.week_start, kind: "sheet", status: "applied").order(:id).select do |import|
      next false if wrote_something_still_there?(import, current)

      OrderImports::Undoer.restore_aliases(import)
      import.update!(status: "pending", applied_at: nil, payload: import.payload.except("undo"))
      true
    end
  end

  def wrote_something_still_there?(import, current)
    Array(import.payload.dig("undo", "after")).any? do |key, by_date|
      product_id, unit = key.split("|")
      by_date.any? { |date, text| text.present? && current.fetch([ product_id.to_i, unit, Date.iso8601(date) ], 0).positive? }
    end
  end
end
