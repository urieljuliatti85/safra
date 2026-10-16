# Um envio de planilhas do histórico: o que mudou em cada aba em relação à importação anterior do mesmo dia.
class SheetImportsController < ApplicationController
  authorize_resource :conference

  def show
    @import = SheetImport.find(params[:id])
    @versions = @import.sorted_versions
  end
end
