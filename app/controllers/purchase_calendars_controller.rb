# Cadastros › Dias de compra: os dias da semana em que se compra na CEASA (esteira simplificada, passo 3).
class PurchaseCalendarsController < ApplicationController
  authorize_resource :purchase_calendar

  def show; end

  def update
    weekdays = Array(params[:weekdays]).compact_blank.map(&:to_i).select { |day| PurchaseCalendar::WEEKDAYS.key?(day) }.uniq.sort
    return redirect_to(purchase_calendar_path, alert: "Marque pelo menos um dia de compra.") if weekdays.empty?

    current_company.update!(purchase_weekdays: weekdays)
    redirect_to purchase_calendar_path, notice: "Dias de compra salvos.", alert: StalePlans.warning(current_company)
  end
end
