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
    result = StockCountSaver.new(date: @date, counts: params.fetch(:counts, {}).to_unsafe_h).call
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
  end

  # Contagem nova muda a compra: se já há uma compra enviada, ela avisa o que mudou depois do envio.
  def stale_purchase_warning
    return nil unless purchase_visible?

    sent = PurchasePlan.where.not(sent_at: nil).distinct.pluck(:date).sort.select do |date|
      latest = PurchasePlan.where(date: date).where.not(sent_at: nil).order(:version).last
      needs = PurchasePlanner.new(company: current_company).call.purchases.fetch(date, [])
      PlanDiff.purchase(latest, needs).any?
    end
    return nil if sent.empty?

    "Atenção: a compra de #{sent.map { |d| Formatting.short_date(d) }.join(', ')} mudou desde a versão enviada."
  end
end
