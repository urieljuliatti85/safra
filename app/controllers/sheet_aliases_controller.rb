# Liga um nome da planilha ("REPOLHO BR. PICADO", "CENTRAL") a um produto, matéria-prima ou cliente, ou o tira
# da comparação.
# Vale para todas as semanas, como os apelidos dos clientes nos pedidos.
class SheetAliasesController < ApplicationController
  authorize_resource :conference

  MODELS = { "product" => Product, "raw_material" => RawMaterial, "customer" => Customer }.freeze

  def create
    target = SheetAlias::TARGETS.include?(params[:target]) ? params[:target] : "product"
    choice = params[:record_id].to_s
    sheet_alias = SheetAlias.find_or_initialize_by(target: target, name: ReferenceSheets::Matcher.key(params[:label]))
    sheet_alias.label = params[:label]
    sheet_alias.ignored = choice == "ignore"
    MODELS.each do |name, model|
      sheet_alias.public_send(:"#{name}=", name == target && !sheet_alias.ignored ? model.find_by(id: choice) : nil)
    end

    back = conference_sheets_path(week: params[:week].presence)
    if sheet_alias.save
      redirect_to back, notice: sheet_alias.ignored ? "\"#{sheet_alias.label}\" fica fora da comparação." : "\"#{sheet_alias.label}\" agora é #{sheet_alias.record.name}."
    else
      redirect_to back, alert: sheet_alias.errors.full_messages.to_sentence
    end
  end
end
