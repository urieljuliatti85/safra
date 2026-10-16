class SuppliersController < ApplicationController
  authorize_resource :supplier
  before_action :load_supplier, only: %i[edit update destroy]

  def index
    @suppliers = Supplier.order(:name).to_a
    @counts = RawMaterial.group(:supplier_id).count
  end

  def new
    @supplier = Supplier.new
  end

  def create
    @supplier = Supplier.new(supplier_params)
    if @supplier.save
      redirect_to suppliers_path, notice: "Fornecedor #{@supplier.name} criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @supplier.update(supplier_params)
      redirect_to suppliers_path, notice: "Fornecedor #{@supplier.name} atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @supplier.destroy
      redirect_to suppliers_path, notice: "Fornecedor #{@supplier.name} excluído."
    else
      redirect_to suppliers_path, alert: "#{@supplier.name} ainda tem matérias-primas. Troque o fornecedor delas antes de excluir."
    end
  end

  private

  def load_supplier
    @supplier = Supplier.find(params[:id])
  end

  def supplier_params
    params.require(:supplier).permit(:name)
  end
end
