# Recebimento e conferência da compra da CEASA (R5.1, R5.2, D47): por item da última versão enviada, o recebido na
# unidade da relação e a divergência. O sistema registra e mostra; o encaminhamento é do responsável.
class PurchaseReceiptsController < ApplicationController
  authorize_resource :purchase_receipt
  before_action :load_receipt

  def show; end

  def update
    errors = []
    PurchaseReceipt.transaction do
      @items.each do |item|
        fields = params.dig(:receipts, item.id.to_s)
        next unless fields

        errors.concat(save_line(item, fields))
      end
      raise ActiveRecord::Rollback if errors.any?
    end
    if errors.empty?
      redirect_to purchase_receipt_path(date: @date), notice: "Recebimento de #{Formatting.short_date(@date)} salvo."
    else
      @errors = errors
      load_receipt
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_receipt
    @date = date_param(:date, Date.current)
    @plan = PurchasePlan.where(date: @date).where.not(sent_at: nil).order(:version).last
    @items = @plan ? @plan.items.includes(:raw_material).sort_by { |i| [ i.raw_material.name, i.unit ] } : []
    @receipts = PurchaseReceipt.where(date: @date).index_by { |r| [ r.raw_material_id, r.unit ] }
  end

  # Tudo vazio apaga o registro (não recebido); um número ou a divergência grava.
  def save_line(item, fields)
    existing = @receipts[[ item.raw_material_id, item.unit ]]
    if fields.values_at(:packages, :loose, :note).all? { |v| v.to_s.strip.empty? }
      existing&.destroy!
      return []
    end

    receipt = existing || PurchaseReceipt.new(date: @date, raw_material: item.raw_material, unit: item.unit)
    receipt.assign_attributes(packages: fields[:packages], loose: fields[:loose], note: fields[:note].to_s.strip.presence)
    receipt.save ? [] : [ "#{item.raw_material.name}: #{receipt.errors.full_messages.to_sentence}" ]
  end
end
