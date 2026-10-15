class OrderImportsController < ApplicationController
  before_action :load_customers
  before_action :load_import, only: %i[show apply]

  def new
    @customer = @customers.find { |c| c.code == params[:customer] } || @customers.first
  end

  def create
    @customer = @customers.find { |c| c.code == params[:customer] }
    file = params[:file]
    if @customer.nil? || file.blank?
      flash.now[:alert] = "Escolha o cliente e a planilha."
      @customer ||= @customers.first
      return render :new, status: :unprocessable_entity
    end

    import = OrderImports::Importer.new(company: current_company, customer: @customer, path: file.tempfile.path, filename: file.original_filename).call
    redirect_to order_import_path(import)
  rescue OrderImports::SheetReader::Unreadable => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def show
    @preview = OrderImports::Preview.new(@import)
    @products = Product.order(:name).group_by(&:product_group)
  end

  def apply
    result = OrderImports::Applier.new(import: @import, mappings: params.fetch(:mappings, {}).to_unsafe_h).call
    if result.ok?
      redirect_to orders_path(customer: @import.customer.code, week: @import.week_start),
                  notice: "Planilha importada no pedido de #{@import.customer.short_name}.", alert: StalePlans.warning(current_company)
    else
      @preview = OrderImports::Preview.new(@import)
      @products = Product.order(:name).group_by(&:product_group)
      @errors = result.errors
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_customers
    @customers = Customer.order(:name).to_a
  end

  def load_import
    @import = OrderImport.find(params[:id])
  end
end
