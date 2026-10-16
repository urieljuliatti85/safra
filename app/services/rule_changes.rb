# Mudanças de regra de produção vindas da tela: antecedência por corte, exceção por produto e a do in natura.
# Serve para salvar e para simular (aplica dentro de uma transação que depois é desfeita).
class RuleChanges
  attr_reader :cut_leads, :raw_lead_days, :exceptions, :new_exception

  # params: { cut_leads: { "<cut_id>" => "1" }, raw_lead_days: "1", exceptions: { "<product_id>" => "2" | "" },
  #           new_exception: { product_id: "", lead_days: "" } }
  def self.from_params(params)
    new(
      cut_leads: params.fetch(:cut_leads, {}).to_unsafe_h,
      raw_lead_days: params[:raw_lead_days],
      exceptions: params.fetch(:exceptions, {}).to_unsafe_h,
      new_exception: params.fetch(:new_exception, {}).to_unsafe_h
    )
  end

  def initialize(cut_leads: {}, raw_lead_days: nil, exceptions: {}, new_exception: {})
    @cut_leads = cut_leads.transform_keys(&:to_i)
    @raw_lead_days = raw_lead_days
    @exceptions = exceptions.transform_keys(&:to_i)
    @new_exception = new_exception.with_indifferent_access
  end

  # Aplica tudo ou nada. Devolve a lista de erros (vazia quando deu certo).
  def apply!(company)
    ActiveRecord::Base.transaction do
      company.update!(raw_lead_days: raw_lead_days) if raw_lead_days.present?
      cut_leads.each { |id, lead| Cut.find(id).update!(lead_days: lead) }
      exceptions.each { |product_id, lead| set_exception(product_id, lead) }
      set_exception(new_exception[:product_id].to_i, new_exception[:lead_days]) if new_exception[:product_id].present?
    end
    []
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    [ e.message ]
  end

  private

  # Vazio apaga a exceção (o produto volta a seguir o corte).
  def set_exception(product_id, lead)
    if lead.blank?
      ProductionRule.where(product_id: product_id).destroy_all
    else
      ProductionRule.find_or_initialize_by(product_id: product_id).update!(lead_days: lead)
    end
  end
end
