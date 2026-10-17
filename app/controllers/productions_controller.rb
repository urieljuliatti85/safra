class ProductionsController < ApplicationController
  authorize_resource :production
  before_action :load_plan

  def show
    respond_to do |format|
      format.html
      format.pdf do
        sector_label = helpers.production_sector_label(@day, @sector) if @sector
        pdf = if @draft
          ProductionPdf.new(result: @result, version: @latest_sent, changes: @changes, sector_label: sector_label)
        else
          notice = "O escritório tem alterações ainda não enviadas. Confira se saiu a versão #{@latest_sent.version + 1} antes de produzir." if @changes.any?
          ProductionPdf.new(result: @result, version: @latest_sent, sector: true, notice: notice, sector_label: sector_label)
        end
        send_data pdf.render, filename: "producao-#{[ @date.iso8601, @sector ].compact.join('-')}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  def publish
    plan = PlanPublisher.production(company: current_company, result: @current, user: current_user)
    redirect_to production_path(date: @date), notice: "Produção de #{Formatting.short_date(@date)} enviada aos setores (versão #{plan.version})."
  end

  private

  # Escritório vê o cálculo atual e a diferença para a versão enviada; os setores veem só a versão enviada,
  # para não produzir números que o escritório ainda não confirmou.
  def load_plan
    @date = date_param(:date, Date.current)
    @current = ProductionPlanner.new(company: current_company, date: @date).call
    @latest_sent = ProductionPlan.latest_sent(@date)
    @changes = @latest_sent ? PlanDiff.production(@latest_sent, @current) : []
    @draft = policy(:production).draft?
    @day = if @draft then @current
    elsif @latest_sent then @latest_sent.to_result
    else ProductionPlanner.result(@date, [])
    end
    @sector = params[:sector].presence_in(@day.sectors)
    @result = @day.for_sector(@sector)
    @versions = ProductionPlan.sent.where(date: @date).includes(:sent_by).order(version: :desc)
    @week = WeekOverview.new(company: current_company, date: @date).call
  end
end
