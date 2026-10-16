# Registra no histórico quem criou, alterou ou excluiu o registro, com o antes e o depois de cada campo.
# Só registra o que passa pelo app com alguém logado (Current.user) ou por uma chave de API (Current.api_token):
# seeds e console não entram.
# Os callbacks rodam dentro da transação: se ela for desfeita (como na simulação de regras), o registro some junto.
#
#   audited except: %w[payload]      # campos que não interessam ao histórico
#   def audit_label = "..."          # como o registro aparece no histórico (padrão: nome ou código)
module Auditable
  extend ActiveSupport::Concern

  ALWAYS_IGNORED = %w[id created_at updated_at company_id].freeze
  HIDDEN = %w[password_digest].freeze
  MAX_TEXT = 200

  included do
    class_attribute :audit_ignored_attributes, default: []
    after_create { record_audit("create") }
    after_update { record_audit("update") }
    after_destroy { record_audit("destroy") }
  end

  class_methods do
    def audited(except: [])
      self.audit_ignored_attributes = Array(except).map(&:to_s)
    end
  end

  def audit_label
    try(:name).presence || try(:code).presence || "#{self.class.model_name.human} ##{id}"
  end

  private

  def record_audit(action)
    user = Current.user
    actor_name = user&.name || (Current.api_token && "API: #{Current.api_token.name}")
    return unless actor_name

    details = audit_details(action)
    return if action == "update" && details.empty?

    company = ActsAsTenant.current_tenant || user&.company || Current.api_token.company
    ActsAsTenant.with_tenant(company) do
      AuditLog.create!(
        company: company, user: user, user_name: actor_name, action: action,
        auditable_type: self.class.name, auditable_id: id, auditable_label: audit_label.to_s.truncate(MAX_TEXT),
        details: details, request_id: Current.request_id, ip_address: Current.ip_address
      )
    end
  end

  # { "Fator" => [antes, depois] }. Na criação o antes é nulo; na exclusão, o depois.
  def audit_details(action)
    pairs = action == "destroy" ? attributes.transform_values { |value| [ value, nil ] } : saved_changes
    pairs.except(*ALWAYS_IGNORED, *audit_ignored_attributes).filter_map do |attribute, (before, after)|
      next if action == "create" && after.nil?

      [ audit_name(attribute), [ audit_value(attribute, before), audit_value(attribute, after) ] ]
    end.to_h
  end

  def audit_name(attribute)
    name = attribute.end_with?("_id") && foreign_reflection(attribute) ? attribute.delete_suffix("_id") : attribute
    self.class.human_attribute_name(HIDDEN.include?(attribute) ? "password" : name)
  end

  def audit_value(attribute, value)
    return nil if value.nil?
    return "[oculta]" if HIDDEN.include?(attribute)

    if (reflection = foreign_reflection(attribute))
      record = reflection.klass.find_by(id: value)
      return record.respond_to?(:audit_label) ? record.audit_label.to_s : "##{value}"
    end

    case value
    when BigDecimal then Formatting.qty(value)
    when Date then value.strftime("%d/%m/%Y")
    when Time, ActiveSupport::TimeWithZone then value.in_time_zone.strftime("%d/%m/%Y %H:%M")
    when true then "sim"
    when false then "não"
    else value.to_s.truncate(MAX_TEXT)
    end
  end

  def foreign_reflection(attribute)
    self.class.reflect_on_all_associations(:belongs_to).find { |reflection| reflection.foreign_key == attribute && !reflection.polymorphic? }
  end
end
