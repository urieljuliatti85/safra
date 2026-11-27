# Estoque da câmara fria: contagem por matéria-prima e dia, em kg. O PurchasePlanner abate da compra o que
# está contado. Campo vazio = não contado (nada é abatido); 0 = câmara vazia. A Produção conta a câmara, mas
# não vê a compra (colunas, link e aviso de compra enviada ficam só para quem acessa Compras).
class StocksController < ApplicationController
  authorize_resource :stock
  before_action :load_date
  helper_method :purchase_visible?

  def show
    load_data
  end

  def update
    result = save_counts
    if result.ok?
      changed = result.changed
      redirect_to stock_path(date: @date, q: params[:q].presence, todas: params[:todas].presence),
                  notice: changed.zero? ? "Nada mudou." : "#{changed} #{changed == 1 ? 'contagem salva' : 'contagens salvas'} em #{Formatting.short_date(@date)}.",
                  alert: stale_purchase_warning
    else
      @errors = result.errors
      load_data
      render :show, status: :unprocessable_entity
    end
  end

  private

  # Matéria-prima e produto pronto numa gravação só: um erro em qualquer um desfaz os dois.
  def save_counts
    result = nil
    ActiveRecord::Base.transaction do
      raw = StockCountSaver.new(date: @date, counts: params.fetch(:counts, {}).to_unsafe_h).call
      ready = ProductStockCountSaver.new(date: @date, counts: params.fetch(:ready_counts, {}).to_unsafe_h).call
      errors = raw.errors + ready.errors
      result = StockCountSaver::Result.new(errors: errors, changed: errors.any? ? 0 : raw.changed + ready.changed)
      raise ActiveRecord::Rollback if errors.any?
    end
    result
  end

  def purchase_visible?
    policy(:purchase).show?
  end

  def load_date
    @date = date_param(:date, Date.current)
  end

  def load_data
    @query = params[:q].to_s.strip
    @all = params[:todas].present?
    @purchase_date = purchase_visible? ? PurchaseDay.where(date: @date..).order(:date).pick(:date) : nil
    needs = @purchase_date ? PurchasePlanner.new(company: current_company).call.purchases.fetch(@purchase_date, []).select { |n| n.unit == "kg" } : []
    @needs = needs.index_by { |n| n.raw_material.id }
    @today = StockCount.where(date: @date).index_by(&:raw_material_id)
    @previous = StockCount.where(date: ...@date).order(:date).each_with_object({}) { |c, latest| latest[c.raw_material_id] = c }
    @raw_materials = RawMaterial.includes(:supplier).order(:name).select do |rm|
      matches = @query.blank? || rm.name.downcase.include?(@query.downcase)
      relevant = @all || !purchase_visible? || @needs.key?(rm.id) || @today.key?(rm.id) || @previous.key?(rm.id)
      matches && relevant
    end
    @total = RawMaterial.count
    load_received
    load_ready
  end

  # Matéria-prima disponível (R5.1, D47): o último saldo contado até o dia, mais o recebido nas compras depois dele
  # (o recebido do mesmo dia da contagem já está nela). Só o que é em kg.
  def load_received
    receipts = PurchaseReceipt.where(unit: "kg", date: ..@date).includes(:raw_material).to_a.group_by(&:raw_material_id)
    @received = receipts.to_h do |raw_material_id, list|
      last = @today[raw_material_id] || @previous[raw_material_id]
      [ raw_material_id, list.select { |r| last.nil? || r.date > last.date }.sum(&:quantity) ]
    end
  end

  # Produto pronto (R3.8, D39): os processados da próxima compra e os que já têm contagem; "Mostrar todas" e quem é
  # da produção veem todos.
  def load_ready
    @ready_used = @needs.values.flat_map { |n| n.ready.to_a }.to_h { |product, quantity| [ product.id, quantity ] }
    in_purchase = @needs.values.flat_map { |n| n.breakdown.map { |b| b.product.id } }.to_set
    @ready_today = ProductStockCount.where(date: @date).index_by(&:product_id)
    @ready_previous = ProductStockCount.where(date: ...@date).order(:date).each_with_object({}) { |c, latest| latest[c.product_id] = c }
    @products = Product.where.not(product_group: "raw").order(:name).select do |product|
      matches = @query.blank? || product.name.downcase.include?(@query.downcase)
      relevant = @all || !purchase_visible? || in_purchase.include?(product.id) || @ready_today.key?(product.id) || @ready_previous.key?(product.id)
      matches && relevant
    end
  end

  # Contagem nova muda a compra: se já há uma compra enviada, ela avisa o que mudou depois do envio.
  def stale_purchase_warning
    return nil unless purchase_visible?

    sent = StalePlans.purchase_dates(current_company)
    return nil if sent.empty?

    "Atenção: a compra de #{sent.map { |d| Formatting.short_date(d) }.join(', ')} mudou desde a versão enviada."
  end
end
