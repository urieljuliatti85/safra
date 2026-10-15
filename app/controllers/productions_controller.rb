class ProductionsController < ApplicationController
  authorize_resource :production
  before_action :load_plan

  def show
    respond_to do |format|
      format.html
      format.pdf do
        send_data ProductionPdf.new(result: @result, version: @latest_sent, changes: @changes).render,
                  filename: "producao-#{@date.iso8601}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  def publish
    plan = PlanPublisher.production(company: current_company, result: @result)
    redirect_to production_path(date: @date), notice: "Produção de #{Formatting.short_date(@date)} enviada aos setores (versão #{plan.version})."
  end

  private

  def load_plan
    @date = date_param(:date, Date.current)
    @result = ProductionPlanner.new(company: current_company, date: @date).call
    @latest_sent = ProductionPlan.where(date: @date).where.not(sent_at: nil).order(:version).last
    @changes = @latest_sent ? PlanDiff.production(@latest_sent, @result) : []
    @by_sector = @result.items.group_by { |item| item.product.sector }
    @week = WeekOverview.new(company: current_company, date: @date).call
  end
end
