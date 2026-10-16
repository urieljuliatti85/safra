# Indicadores da semana: volume, perdas, compras e quem mais pede. Só leitura, a partir dos mesmos dados da API de BI.
class IndicatorsController < ApplicationController
  authorize_resource :indicator

  def show
    date = params[:week].present? ? Date.iso8601(params[:week].to_s) : Date.current
    @summary = IndicatorsSummary.new(company: current_company, date: date).call
  rescue Date::Error
    redirect_to indicators_path, alert: "Semana inválida."
  end
end
