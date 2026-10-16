class PurchaseDaysController < ApplicationController
  authorize_resource :purchase_day

  def create
    date = date_param(:date, nil)
    return redirect_to(rules_path(anchor: "compras"), alert: "Escolha uma data válida para a compra.") unless date

    day = PurchaseDay.find_or_create_by(date: date)
    redirect_to rules_path(anchor: "compras"), notice: "Dia de compra #{Formatting.weekday_date(date)} #{day.previously_new_record? ? 'adicionado' : 'já existia'}.", alert: StalePlans.warning(current_company)
  end

  def destroy
    day = PurchaseDay.find(params[:id])
    day.destroy!
    redirect_to rules_path(anchor: "compras"), notice: "Dia de compra #{Formatting.weekday_date(day.date)} removido.", alert: StalePlans.warning(current_company)
  end
end
