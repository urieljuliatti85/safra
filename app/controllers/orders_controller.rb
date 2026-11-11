class OrdersController < ApplicationController
  authorize_resource :order
  before_action :load_context

  def index
    return render :empty if @customer.nil?

    @add_product = Product.find_by(id: params[:add])
    @focus_date = date_param(:dia, nil)
    @imports = OrderImport.where(customer: @customer, week_start: @week_start, kind: "sheet", status: "applied").order(applied_at: :desc)
    # Pedidos em imagem do cliente e da semana: atalho para voltar ao print ao lado da grade.
    @images = OrderImport.images.where(customer: @customer, week_start: @week_start).order(:created_at)
    build_grid
  end

  def update
    return head(:unprocessable_entity) if @customer.nil?

    result = if (missing = EntryType.missing(params[:entry_type]))
      OrderGridSaver::Result.new(errors: [ missing ], changed_dates: [])
    else
      OrderGridSaver.new(order: @order, quantities: params.fetch(:quantities, {}).to_unsafe_h,
                         measures: params.fetch(:measures, {}).to_unsafe_h, entry_type: params[:entry_type],
                         late_confirmed: params[:late_confirmed] == "1", explicit_removal: true).call
    end
    if result.ok?
      redirect_to orders_path(customer: @customer.code, week: @week_start), notice: saved_notice(result), alert: StalePlans.warning(current_company)
    else
      @errors = result.errors
      @add_product = nil
      build_grid
      render :index, status: :unprocessable_entity
    end
  end

  # Quando o pedido chegou do cliente (R1.4, D7). O aviso de prazo na conferência compara com esta hora.
  def received
    return head(:unprocessable_entity) if @customer.nil?

    back = orders_path(customer: @customer.code, week: @week_start)
    time = Time.zone.parse(params[:received_at].to_s)
    return redirect_to(back, alert: "Informe a data e a hora em que o pedido chegou.") if time.nil?

    @order.update!(received_at: time)
    redirect_to back, notice: "Pedido recebido em #{Formatting.short_date(time)} às #{time.strftime('%H:%M')}."
  end

  # "Cancelar item" (R1.38, D23): tira do pedido os dias marcados de uma linha da grade (produto e unidade), com a
  # confirmação das 48 h quando vale (R1.26). A versão registra cada dia como "cancelado". back: a tela de onde veio
  # (a grade ou o pedido em imagem).
  def cancel_items
    return head(:unprocessable_entity) if @customer.nil?

    back = safe_back || orders_path(customer: @customer.code, week: @week_start)
    row = params[:row].to_s
    days = Array(params[:cancel]).map(&:to_s).select { |key| key.start_with?("#{row}|") && key.count("|") == 2 }
    return redirect_to(back, alert: "Marque o dia do item a cancelar.") if row.empty? || days.empty?

    quantities = { row => days.to_h { |key| [ key.split("|").last, "0" ] } }
    result = OrderGridSaver.new(order: @order, quantities: quantities, source: "cancel",
                                late_confirmed: params.dig(:late_confirmed, row) == "1").call
    if !result.ok?
      redirect_to back, alert: result.errors.to_sentence(last_word_connector: " ")
    elsif result.changed_dates.empty?
      redirect_to back, notice: "Nada foi cancelado: o item já não estava nesses dias."
    else
      redirect_to back, notice: "Item cancelado: versão #{@order.versions.maximum(:version)}.", alert: StalePlans.warning(current_company)
    end
  end

  private

  # Só caminho do próprio app ("/orders...", "/order_imports/5"), nunca outro site.
  def safe_back
    path = params[:back].to_s
    path if path.start_with?("/") && !path.start_with?("//")
  end

  def load_context
    @customers = Customer.order(:name)
    @customer = @customers.find { |c| c.code == params[:customer] } || @customers.first
    @week_start = date_param(:week, Date.current.beginning_of_week)
    @order = Order.find_or_create_by!(customer: @customer, week_start: @week_start) if @customer
    # Grade do extra (?tipo=extra) ou tipo já escolhido na tela "Importar" (?tipo=new|alteration).
    @tipo = OrderVersion::ENTRY_TYPES.key?(params[:tipo]) ? params[:tipo] : nil
    @tipo = "extra" if params[:entry_type] == "extra"
  end

  # Salvar sem mudar nada não grava versão: a mensagem diz isso, para ninguém procurar a versão que não existe.
  def saved_notice(result)
    if result.changed_dates.empty?
      return "Medida salva. As quantidades não mudaram, então não há versão nova." if result.measures_changed

      return "Nada mudou no pedido: as quantidades já eram essas. Nenhuma versão nova."
    end

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
  end
end
