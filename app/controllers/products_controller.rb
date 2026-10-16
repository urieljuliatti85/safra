class ProductsController < ApplicationController
  authorize_resource :product
  before_action :load_product, only: %i[edit update destroy]
  before_action :load_options, only: %i[new create edit update]

  def index
    @group = Product::GROUPS.include?(params[:group]) ? params[:group] : nil
    @query = params[:q].to_s.strip
    scope = Product.includes(:raw_material, :cut).order(:name)
    scope = scope.where(product_group: @group) if @group
    scope = scope.where("products.name ILIKE ?", "%#{Product.sanitize_sql_like(@query)}%") if @query.present?
    @products = scope.to_a
  end

  def new
    @product = Product.new(product_group: "processed", unit: "kg")
  end

  def create
    @product = Product.new(product_params)
    @product.code = CodeGenerator.call(Product, @product.name, prefix: (@product.raw? ? "in_" : nil))
    if @product.save
      redirect_to products_path(q: @product.name), notice: "Produto #{@product.name} criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to products_path(q: @product.name), notice: "Produto #{@product.name} atualizado.", alert: StalePlans.warning(current_company)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @product.destroy
      redirect_to products_path, notice: "Produto #{@product.name} excluído."
    else
      redirect_to products_path(q: @product.name), alert: "#{@product.name} já tem linhas de pedido e não pode ser excluído."
    end
  end

  private

  def load_product
    @product = Product.find(params[:id])
  end

  def load_options
    @raw_materials = RawMaterial.order(:name)
    @cuts = Cut.order(:sector_name, :name)
  end

  # Produto in natura não tem corte: o campo é ignorado.
  def product_params
    permitted = params.require(:product).permit(:name, :product_group, :raw_material_id, :cut_id, :unit)
    permitted[:cut_id] = nil if permitted[:product_group] == "raw"
    permitted
  end
end
