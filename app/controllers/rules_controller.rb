# Regras de produção editáveis: antecedência por corte e por produto, in natura e dias de compra.
# "Ver efeito" simula sem gravar e mostra o placar contra as planilhas antes e depois.
class RulesController < ApplicationController
  authorize_resource :rule
  before_action :load_data

  def show
  end

  def update
    @changes = RuleChanges.from_params(params)
    if params[:commit_action] == "simulate"
      @simulation = RuleSimulation.new(company: current_company, changes: @changes).call
      @errors = @simulation.errors
      render :show, status: (@errors.any? ? :unprocessable_entity : :ok)
    else
      @errors = @changes.apply!(current_company)
      if @errors.empty?
        redirect_to rules_path, notice: "Regras salvas.", alert: StalePlans.warning(current_company)
      else
        current_company.reload
        render :show, status: :unprocessable_entity
      end
    end
  end

  private

  def load_data
    @cuts = Cut.order(:sector, :name).to_a
    @products_per_cut = Product.group(:cut_id).count
    @exceptions = ProductionRule.includes(:product).sort_by { |rule| rule.product.name }
    @exception_candidates = Product.where.not(product_group: "raw").where.not(id: ProductionRule.select(:product_id)).order(:name)
    @purchase_days = PurchaseDay.order(:date)
    @scores = SheetComparison.new(current_company).scores
  end
end
