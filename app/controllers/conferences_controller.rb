class ConferencesController < ApplicationController
  def show
    @alerts = ConferenceChecker.new(company: current_company).call
  end

  def sheets
    @comparison = SheetComparison.new(current_company)
  end
end
