# Uma versão do pedido de um cliente/semana: o que mudou nela e o botão de voltar o pedido a ela.
class OrderVersionsController < ApplicationController
  authorize_resource :order_version
  before_action :load_version

  def show
    @order = @version.order
    @products = Product.where(id: @version.lines.map { |line| line["product_id"] }).index_by(&:id)
  end

  def restore
    order = @version.order
    result = OrderVersionRestorer.new(version: @version).call
    if result.ok?
      redirect_to orders_path(customer: order.customer.code, week: order.week_start),
                  notice: "Pedido de #{order.customer.short_name} voltou à versão #{@version.version}.", alert: StalePlans.warning(current_company)
    else
      redirect_to order_version_path(@version), alert: result.errors.to_sentence
    end
  end

  private

  def load_version
    @version = OrderVersion.includes(order: :customer).find(params[:id])
  end
end
