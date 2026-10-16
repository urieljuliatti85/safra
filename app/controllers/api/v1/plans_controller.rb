# Programação, produção e compras já calculadas pelo sistema (só leitura), com a versão enviada e a diferença.
module Api
  module V1
    class PlansController < BaseController
      def schedule
        date = date_param(:date, Date.current)
        render json: ApiPresenter.schedule(date, ScheduleBuilder.new(company: current_company, date: date).call)
      end

      def production
        date = date_param(:date, Date.current)
        result = ProductionPlanner.new(company: current_company, date: date).call
        sent = ProductionPlan.where(date: date).where.not(sent_at: nil).order(:version).last
        render json: ApiPresenter.production(result, sent, sent ? PlanDiff.production(sent, result) : [])
      end

      def purchases
        dates = PurchaseDay.order(:date).pluck(:date)
        date = date_param(:date, dates.reverse.find { |d| d <= Date.current } || dates.first)
        needs = date ? PurchasePlanner.new(company: current_company).call.purchases.fetch(date, []) : []
        sent = date && PurchasePlan.where(date: date).where.not(sent_at: nil).order(:version).last
        render json: ApiPresenter.purchase(date, needs, sent, sent ? PlanDiff.purchase(sent, needs) : [])
      end
    end
  end
end
