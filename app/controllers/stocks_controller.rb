# Estoque da câmara fria: contagem por matéria-prima e dia, em kg. O PurchasePlanner abate da compra o que
# está contado. Campo vazio = não contado (nada é abatido); 0 = câmara vazia.
class StocksController < ApplicationController
  authorize_resource :stock
  before_action :load_date

  def show
    load_data
  end

  def update
    errors = []
    changed = 0
    StockCount.transaction do
      RawMaterial.where(id: params.fetch(:counts, {}).keys).find_each do |raw_material|
        text = params[:counts][raw_material.id.to_s].to_s.strip
        existing = StockCount.find_by(raw_material: raw_material, date: @date)
        if text.empty?
          existing&.destroy!
          changed += 1 if existing
          next
        end

        record = existing || StockCount.new(raw_material: raw_material, date: @date)
        record.kg = text
        next unless record.new_record? || record.changed?

        if record.save
          changed += 1
        else
          errors << "#{raw_material.name}: #{record.errors.full_messages.to_sentence}"
        end
      end
      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.empty?
      redirect_to stock_path(date: @date, q: params[:q].presence, todas: params[:todas].presence),
                  notice: changed.zero? ? "Nada mudou." : "#{changed} #{changed == 1 ? 'contagem salva' : 'contagens salvas'} em #{Formatting.short_date(@date)}.",
                  alert: stale_purchase_warning
    else
      @errors = errors
      load_data
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_date
    @date = date_param(:date, Date.current)
  end

  def load_data
    @query = params[:q].to_s.strip
    @all = params[:todas].present?
    result = PurchasePlanner.new(company: current_company).call
    @purchase_date = PurchaseDay.where(date: @date..).order(:date).pick(:date)
    needs = @purchase_date ? result.purchases.fetch(@purchase_date, []).select { |n| n.unit == "kg" } : []
    @needs = needs.index_by { |n| n.raw_material.id }
    @today = StockCount.where(date: @date).index_by(&:raw_material_id)
    @previous = StockCount.where(date: ...@date).order(:date).each_with_object({}) { |c, latest| latest[c.raw_material_id] = c }
    @raw_materials = RawMaterial.includes(:supplier).order(:name).select do |rm|
      matches = @query.blank? || rm.name.downcase.include?(@query.downcase)
      relevant = @all || @needs.key?(rm.id) || @today.key?(rm.id) || @previous.key?(rm.id)
      matches && relevant
    end
    @total = RawMaterial.count
  end

  # Contagem nova muda a compra: se já há uma compra enviada, ela avisa o que mudou depois do envio.
  def stale_purchase_warning
    sent = PurchasePlan.where.not(sent_at: nil).distinct.pluck(:date).sort.select do |date|
      latest = PurchasePlan.where(date: date).where.not(sent_at: nil).order(:version).last
      needs = PurchasePlanner.new(company: current_company).call.purchases.fetch(date, [])
      PlanDiff.purchase(latest, needs).any?
    end
    return nil if sent.empty?

    "Atenção: a compra de #{sent.map { |d| Formatting.short_date(d) }.join(', ')} mudou desde a versão enviada."
  end
end
