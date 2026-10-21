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
    if @current.items.empty? && params[:empty] != "1"
      return redirect_to production_path(date: @date), alert: "#{empty_message} Confirme para enviar mesmo assim."
    end

    plan = PlanPublisher.production(company: current_company, result: @current, user: current_user)
    SendProductionVersionPushJob.perform_later(plan.id)
    redirect_to production_path(date: @date), notice: "Produção de #{Formatting.short_date(@date)} enviada aos setores (versão #{plan.version})."
  end

  private

  # Escritório vê o cálculo atual e a diferença para a versão enviada; os setores veem só a versão enviada,
  # para não produzir números que o escritório ainda não confirmou.
  def load_plan
    @date = date_param(:date, Date.current)
    planner = ProductionPlanner.new(company: current_company, date: @date)
    @current = planner.call
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
    return unless @draft

    @raw_lines = planner.raw_lines
    @purchase_date = PurchaseDay.where(date: ..@date).maximum(:date)
    @raw_note = raw_note
    @empty_message = empty_message if @current.items.empty?
  end

  # Por que a produção do dia está vazia, para o aviso da tela e a confirmação do envio.
  def empty_message
    [ "Nenhum item para produzir em #{Formatting.short_date(@date)}.", @raw_note ].compact.join(" ")
  end

  # "As 105 linhas in natura de Horizonte Norte (entregas de 19/10) vão direto para a compra."
  def raw_note
    return if @raw_lines.blank?

    count = @raw_lines.size
    customers = @raw_lines.map { |line| line.order.customer.short_name }.uniq.sort.to_sentence
    deliveries = @raw_lines.map(&:delivery_date).uniq.sort.map { |d| Formatting.short_date(d) }.to_sentence
    lines = count == 1 ? "A linha in natura" : "As #{count} linhas in natura"
    "#{lines} de #{customers} (#{count == 1 ? 'entrega' : 'entregas'} de #{deliveries}) " \
      "#{count == 1 ? 'vai' : 'vão'} direto para a compra."
  end
end
