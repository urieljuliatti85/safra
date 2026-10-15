class SchedulesController < ApplicationController
  def show
    @date = date_param(:date, Date.current)
    @groups = ScheduleBuilder.new(company: current_company, date: @date).call
    respond_to do |format|
      format.html
      format.pdf do
        send_data SchedulePdf.new(date: @date, groups: @groups).render,
                  filename: "programacao-#{@date.iso8601}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end
end
