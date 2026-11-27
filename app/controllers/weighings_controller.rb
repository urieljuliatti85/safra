# Pesagem (R2.6, R2.7; esteira simplificada, passo 5): checklist do dia de entrega, por cliente, com o peso real em kg de
# cada item, que vai para o faturamento. A quantidade e a unidade do pedido não mudam.
class WeighingsController < ApplicationController
  authorize_resource :weighing
  before_action :load_date

  def show
    load_stops
  end

  def update
    result = WeighingSaver.new(date: @date, weights: params.fetch(:weights, {}).to_unsafe_h).call
    if result.ok?
      changed = result.changed
      redirect_to weighing_path(date: @date),
                  notice: changed.zero? ? "Nada mudou." : "#{changed} #{changed == 1 ? 'peso salvo' : 'pesos salvos'} na entrega de #{Formatting.short_date(@date)}."
    else
      @errors = result.errors
      load_stops
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_date
    @date = date_param(:date, Date.current)
  end

  # Ao voltar com erro, o campo mostra o que foi digitado.
  def load_stops
    @stops = WeighingList.new(company: current_company, date: @date).call
    @typed = params.fetch(:weights, {}).to_unsafe_h if @errors.present?
  end
end
