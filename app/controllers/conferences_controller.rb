class ConferencesController < ApplicationController
  authorize_resource :conference

  # Uma semana por vez (a atual, se nenhuma for pedida) ou todas (?week=todas). A semana de um alerta é a da entrega.
  def show
    @all_weeks = params[:week] == "todas"
    @week = @all_weeks ? nil : (date_param(:week, nil)&.beginning_of_week || Date.current.beginning_of_week)
    @alerts = ConferenceChecker.new(company: current_company, week: @week).call
    @attention_total = @all_weeks ? @alerts.count { |a| a.level == :warn } : ConferenceChecker.new(company: current_company).call.count { |a| a.level == :warn }
    @groups = @alerts.group_by(&:kind).sort_by { |_, alerts| [ alerts.any? { |a| a.level == :warn } ? 0 : 1, -alerts.size ] }
  end

  # Uma semana por vez (a mais recente importada, se nenhuma for pedida).
  def sheets
    @weeks = ReferenceSheet.weeks
    @week = date_param(:week, nil)&.beginning_of_week || @weeks.first
    return unless @week

    @comparison = SheetComparison.new(current_company, dates: @week..(@week + 6))
    @imports = SheetImport.where(week_start: @week).newest_first.includes(:user)
    respond_to do |format|
      format.html do
        @choices = { "product" => Product.order(:name), "raw_material" => RawMaterial.order(:name), "customer" => Customer.order(:name) } if @comparison.unmatched.any?
      end
      format.pdf do
        send_data ComparisonPdf.new(comparison: @comparison, week: @week).render,
                  filename: "planilhas-x-safra-#{@week.iso8601}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end
end
