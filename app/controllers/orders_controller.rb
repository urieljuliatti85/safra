class OrdersController < ApplicationController
  authorize_resource :order
  before_action :load_context

  def index
    return render :empty if @customer.nil?

    @add_product = Product.find_by(id: params[:add])
    @imports = OrderImport.where(customer: @customer, week_start: @week_start, kind: "sheet", status: "applied").order(applied_at: :desc)
    build_grid
  end

  def update
    return head(:unprocessable_entity) if @customer.nil?

    result = OrderGridSaver.new(order: @order, quantities: params.fetch(:quantities, {}).to_unsafe_h).call
    if result.ok?
      redirect_to orders_path(customer: @customer.code, week: @week_start), notice: "Pedido salvo.", alert: StalePlans.warning(current_company)
    else
      @errors = result.errors
      @add_product = nil
      build_grid
      render :index, status: :unprocessable_entity
    end
  end

  private

  def load_context
    @customers = Customer.order(:name)
    @customer = @customers.find { |c| c.code == params[:customer] } || @customers.first
    @week_start = date_param(:week, Date.current.beginning_of_week)
    @order = Order.find_or_create_by!(customer: @customer, week_start: @week_start) if @customer
  end

  def build_grid
    @grid = OrderGrid.new(order: @order, add_product: @add_product)
  end
end
