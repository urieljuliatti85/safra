class ConferencesController < ApplicationController
  authorize_resource :conference

  def show
    @alerts = ConferenceChecker.new(company: current_company).call
    @groups = @alerts.group_by(&:kind).sort_by { |_, alerts| [ alerts.any? { |a| a.level == :warn } ? 0 : 1, -alerts.size ] }
  end

  def sheets
    @comparison = SheetComparison.new(current_company)
  end
end
