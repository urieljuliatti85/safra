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
      redirect_to orders_path(customer: @customer.code, week: @week_start), notice: saved_notice(result), alert: StalePlans.warning(current_company)
    else
      @errors = result.errors
      @add_product = nil
      build_grid
      render :index, status: :unprocessable_entity
    end
  end

  def copy_previous
    return head(:unprocessable_entity) if @customer.nil?

    result = OrderWeekCopier.new(order: @order).call
    if result.ok?
      redirect_to orders_path(customer: @customer.code, week: @week_start), alert: StalePlans.warning(current_company),
                  notice: "Pedido da semana de #{Formatting.short_date(@week_start - 7)} copiado, com as entregas 7 dias depois. Confira e ajuste o que mudou."
    else
      redirect_to orders_path(customer: @customer.code, week: @week_start), alert: result.errors.to_sentence
    end
  end

  private

  def load_context
    @customers = Customer.order(:name)
    @customer = @customers.find { |c| c.code == params[:customer] } || @customers.first
    @week_start = date_param(:week, Date.current.beginning_of_week)
    @order = Order.find_or_create_by!(customer: @customer, week_start: @week_start) if @customer
  end

  # Salvar sem mudar nada não grava versão: a mensagem diz isso, para ninguém procurar a versão que não existe.
  def saved_notice(result)
    return "Nada mudou no pedido: as quantidades já eram essas. Nenhuma versão nova." if result.changed_dates.empty?

    version = @order.versions.maximum(:version)
    "Pedido salvo: versão #{version}, #{plural_changes(@order.versions.find_by(version: version))}."
  end

  def plural_changes(version)
    count = version&.changes_list&.size.to_i
    "#{count} #{count == 1 ? 'alteração' : 'alterações'}"
  end

  def build_grid
    @grid = OrderGrid.new(order: @order, add_product: @add_product)
    @versions = @order.versions.newest_first.includes(:user)
    @copy_count = @grid.rows.empty? ? OrderWeekCopier.new(order: @order).previous_lines_count : 0
  end
end
