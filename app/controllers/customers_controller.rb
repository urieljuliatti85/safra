class CustomersController < ApplicationController
  authorize_resource :customer
  before_action :load_customer, only: %i[edit update destroy]

  def index
    @customers = Customer.order(:name).to_a
    @alias_counts = CustomerAlias.group(:customer_id).count
    @line_counts = OrderLine.joins(:order).group("orders.customer_id").count
  end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)
    @customer.code = CodeGenerator.call(Customer, @customer.short_name.presence || @customer.name)
    if @customer.save
      redirect_to edit_customer_path(@customer), notice: "Cliente #{@customer.name} criado. Se quiser, já cadastre os apelidos dos produtos."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_aliases
  end

  def update
    if @customer.update(customer_params)
      redirect_to customers_path, notice: "Cliente #{@customer.name} atualizado."
    else
      load_aliases
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @customer.destroy
      redirect_to customers_path, notice: "Cliente #{@customer.name} excluído."
    else
      redirect_to customers_path, alert: "#{@customer.name} já tem pedidos e não pode ser excluído."
    end
  end

  private

  def load_customer
    @customer = Customer.find(params[:id])
  end

  def load_aliases
    @aliases = @customer.aliases.includes(:product).sort_by { |a| a.name_in_order.downcase }
    @products = Product.order(:name)
  end

  def customer_params
    params.require(:customer).permit(:name, :short_name, :order_source, :monthly_orders, :address, :district, :city, :state, :postal_code,
                                     :latitude, :longitude, :delivery_from, :delivery_until, :delivery_notes)
  end
end
