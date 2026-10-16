# Apelidos: como o cliente escreve cada produto no pedido. Confirmado uma vez, reconhecido sempre.
class CustomerAliasesController < ApplicationController
  authorize_resource :customer_alias
  before_action :load_customer

  def create
    record = @customer.aliases.new(params.require(:customer_alias).permit(:name_in_order, :product_id))
    if record.save
      redirect_to edit_customer_path(@customer, anchor: "apelidos"), notice: "Apelido \"#{record.name_in_order}\" cadastrado."
    else
      redirect_to edit_customer_path(@customer, anchor: "apelidos"), alert: record.errors.full_messages.to_sentence
    end
  end

  def destroy
    record = @customer.aliases.find(params[:id])
    record.destroy!
    redirect_to edit_customer_path(@customer, anchor: "apelidos"), notice: "Apelido \"#{record.name_in_order}\" removido."
  end

  private

  def load_customer
    @customer = Customer.find(params[:customer_id])
  end
end
