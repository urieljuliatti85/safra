# Cortes: como um produto processado é feito (cubos, cubinhos, ralado...). O corte define o setor de produção e a
# antecedência. O código é gerado do nome e não muda depois.
class CutsController < ApplicationController
  authorize_resource :cut
  before_action :load_cut, only: %i[edit update destroy]

  def index
    @cuts = Cut.order(:name).to_a.sort_by { |cut| [ Cut::SECTORS.index(cut.sector), cut.name ] }
    @product_counts = Product.group(:cut_id).count
  end

  def new
    @cut = Cut.new(sector: "manual", lead_days: 1)
  end

  def create
    @cut = Cut.new(cut_params)
    @cut.code = CodeGenerator.call(Cut, @cut.name)
    if @cut.save
      redirect_to cuts_path, notice: "Corte #{@cut.name} criado. Agora é só escolhê-lo ao cadastrar os produtos."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @products_count = @cut.products.count
  end

  def update
    if @cut.update(cut_params)
      redirect_to cuts_path, notice: "Corte #{@cut.name} atualizado.", alert: StalePlans.warning(current_company)
    else
      @products_count = @cut.products.count
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @cut.destroy
      redirect_to cuts_path, notice: "Corte #{@cut.name} excluído."
    else
      redirect_to cuts_path, alert: "#{@cut.name} ainda tem produtos. Troque o corte deles antes de excluir."
    end
  end

  private

  def load_cut
    @cut = Cut.find(params[:id])
  end

  # O nome do setor não vem da tela: segue o do setor escolhido.
  def cut_params
    params.require(:cut).permit(:name, :sector, :lead_days, :reference_measure)
  end
end
