# Uma versão enviada aos setores, como foi enviada: o que mudou em relação à anterior, a lista completa e o PDF.
class ProductionVersionsController < ApplicationController
  before_action { authorize :production, :show? }

  def show
    @plan = ProductionPlan.sent.includes(:sent_by).find(params[:id])
    @latest = ProductionPlan.latest_sent(@plan.date)
    respond_to do |format|
      format.html
      format.pdf do
        notice = "Versão substituída pela v#{@latest.version}. Não use para produzir." unless @plan == @latest
        pdf = ProductionPdf.new(result: @plan.to_result, version: @plan, sector: true, notice: notice)
        send_data pdf.render, filename: "producao-#{@plan.date.iso8601}-v#{@plan.version}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end
end
