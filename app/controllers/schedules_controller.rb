class SchedulesController < ApplicationController
  authorize_resource :schedule

  def show
    @date = date_param(:date, Date.current)
    @end_date = @date + ScheduleBuilder::PERIOD_DAYS - 1
    @groups = ScheduleBuilder.new(company: current_company, date: @date, days: ScheduleBuilder::PERIOD_DAYS).call
    respond_to do |format|
      format.html
      format.pdf do
        send_data SchedulePdf.new(date: @date, end_date: @end_date, groups: @groups).render,
                  filename: "programacao-#{@date.iso8601}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  # Troca a marca de um item: quadrado (produzir no dia) ou ponto (já pronto). Só a marca muda, nunca a quantidade.
  def mark
    line = OrderLine.find(params[:id])
    line.update!(schedule_mark: params.require(:mark))
    redirect_to schedule_path(date: date_param(:date, line.delivery_date), anchor: "linha-#{line.id}"), status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to schedule_path(date: date_param(:date, Date.current)), alert: "Marca inválida.", status: :see_other
  end
end
