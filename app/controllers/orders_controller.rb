class OrdersController < ApplicationController
  before_action :load_context

  def index
    @add_product = Product.find_by(id: params[:add])
    build_grid
  end

  def update
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
    @dates = (@week_start..(@week_start + 7)).to_a
    @order = Order.find_or_create_by!(customer: @customer, week_start: @week_start)
  end

  def build_grid
    lines = @order.lines.includes(:product).to_a
    @cells = lines.group_by { |l| [ l.product_id, l.unit ] }
    @rows = @cells.keys.map { |product_id, unit| [ lines.find { |l| l.product_id == product_id }.product, unit ] }
    @rows << [ @add_product, @add_product.unit ] if @add_product && @rows.none? { |p, u| p == @add_product && u == @add_product.unit }
    @rows = @rows.sort_by { |product, unit| [ Product::GROUPS.index(product.product_group), product.name, unit ] }
    @sections = @rows.group_by { |product, _| product.product_group }
    @available_products = Product.order(:name).includes(:raw_material)
  end
end
