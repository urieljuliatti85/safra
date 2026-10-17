class PurchasesController < ApplicationController
  authorize_resource :purchase
  before_action :load_plan

  def show
    respond_to do |format|
      format.html
      format.pdf do
        send_data PurchasePdf.new(date: @date, suppliers: @suppliers, version: @latest_sent, changed: @changes.any?).render,
                  filename: "compras-#{@date.iso8601}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  def publish
    plan = PlanPublisher.purchase(company: current_company, date: @date, needs: @needs)
    redirect_to purchases_path(date: @date), notice: "Compra de #{Formatting.short_date(@date)} enviada (versão #{plan.version})."
  end

  private

  def load_plan
    @purchase_dates = PurchaseDay.order(:date).pluck(:date)
    @date = date_param(:date, @purchase_dates.reverse.find { |d| d <= Date.current } || @purchase_dates.first)
    @result = PurchasePlanner.new(company: current_company).call
    @needs = @result.purchases.fetch(@date, [])
    @suppliers = @needs.group_by { |n| n.raw_material.supplier&.name || "Sem fornecedor" }.sort_by { |name, _| [ name == "Sem fornecedor" ? 1 : 0, name ] }
    @week = WeekOverview.new(company: current_company, date: @date).call if @date
    @latest_sent = PurchasePlan.where(date: @date).where.not(sent_at: nil).order(:version).last
    @changes = @latest_sent ? PlanDiff.purchase(@latest_sent, @needs) : []
  end
end
