# Painel inicial do escritório: etapa de cada trabalho do dia e pendências.
class DashboardsController < ApplicationController
  authorize_resource :dashboard

  def show
    @summary = DashboardSummary.new(company: current_company).call
  end
end
