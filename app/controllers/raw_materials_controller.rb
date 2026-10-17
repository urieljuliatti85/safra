# Matérias-primas e seus fatores. O índice é uma grade editável em lote: é onde se completa o que falta
# (fator de perda, peso da embalagem, fornecedor) para a compra virar número de caixas e sacos.
class RawMaterialsController < ApplicationController
  FILTERS = %w[all incomplete used no_supplier].freeze
  BULK_FIELDS = %i[supplier_id purchase_package multiply_factor kg_per_package kg_per_peeled_box].freeze

  authorize_resource :raw_material
  before_action :load_raw_material, only: %i[edit update destroy]

  def index
    load_index
  end

  def bulk_update
    attributes = params.fetch(:raw_materials, {})
    errors = []
    updated = 0
    RawMaterial.transaction do
      RawMaterial.where(id: attributes.keys).find_each do |raw_material|
        raw_material.assign_attributes(attributes.fetch(raw_material.id.to_s).permit(*BULK_FIELDS))
        next unless raw_material.changed?

        if raw_material.save
          updated += 1
        else
          errors << "#{raw_material.name}: #{raw_material.errors.full_messages.to_sentence}"
        end
      end
      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.empty?
      redirect_to raw_materials_path(filter: params[:filter], q: params[:q].presence),
                  notice: updated.zero? ? "Nada mudou." : "#{updated} #{updated == 1 ? 'matéria-prima atualizada' : 'matérias-primas atualizadas'}.",
                  alert: StalePlans.warning(current_company)
    else
      @errors = errors
      load_index
      render :index, status: :unprocessable_entity
    end
  end

  def new
    @raw_material = RawMaterial.new(purchase_package: "cx")
  end

  def create
    @raw_material = RawMaterial.new(raw_material_params)
    @raw_material.code = CodeGenerator.call(RawMaterial, @raw_material.name)
    if @raw_material.save
      redirect_to raw_materials_path(q: @raw_material.name), notice: "Matéria-prima #{@raw_material.name} criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @raw_material.update(raw_material_params)
      redirect_to raw_materials_path(q: @raw_material.name), notice: "Matéria-prima #{@raw_material.name} atualizada.", alert: StalePlans.warning(current_company)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @raw_material.destroy
      redirect_to raw_materials_path, notice: "Matéria-prima #{@raw_material.name} excluída."
    else
      redirect_to raw_materials_path(q: @raw_material.name), alert: "#{@raw_material.name} ainda tem produtos. Exclua ou mude os produtos antes."
    end
  end

  private

  def load_raw_material
    @raw_material = RawMaterial.find(params[:id])
  end

  def raw_material_params
    params.require(:raw_material).permit(:name, :supplier_id, :purchase_package, :multiply_factor, :kg_per_package, :kg_per_peeled_box, :note)
  end

  def load_index
    @filter = FILTERS.include?(params[:filter]) ? params[:filter] : "all"
    @query = params[:q].to_s.strip
    processed_ids = Product.where.not(product_group: "raw").distinct.pluck(:raw_material_id).to_set
    @used_ids = Product.joins(:order_lines).distinct.pluck(:raw_material_id).to_set
    all = RawMaterial.includes(:supplier).order(:name).to_a
    @incomplete_count = all.count { |rm| incomplete?(rm, processed_ids) }
    @no_supplier_count = all.count { |rm| rm.supplier.nil? }
    @flags = all.to_h { |rm| [ rm.id, { factor: rm.missing_factor? && processed_ids.include?(rm.id), package: rm.missing_package_weight? } ] }
    @raw_materials = all.select do |rm|
      (@query.blank? || rm.name.downcase.include?(@query.downcase) || rm.code.include?(@query.downcase)) &&
        (@filter == "all" || (@filter == "incomplete" && incomplete?(rm, processed_ids)) || (@filter == "used" && @used_ids.include?(rm.id)) ||
         (@filter == "no_supplier" && rm.supplier.nil?))
    end
    @suppliers = Supplier.order(:name)
    @scores = SheetComparison.new(current_company).scores[:purchase]
  end

  def incomplete?(raw_material, processed_ids)
    (raw_material.missing_factor? && processed_ids.include?(raw_material.id)) || raw_material.missing_package_weight?
  end
end
