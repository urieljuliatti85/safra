# Consulta do histórico: filtra, agrupa o que veio de uma mesma ação (mesmo request_id) e pagina por ação.
class AuditTrail
  PER_PAGE = 30
  GROUP_KEY = Arel.sql("COALESCE(audit_logs.request_id, audit_logs.id::text)")

  Event = Data.define(:key, :user_id, :user_name, :at, :ip_address, :logs)
  Result = Data.define(:events, :total, :page, :pages)

  def initialize(filters: {}, page: 1)
    @filters = filters
    @page = [ page.to_i, 1 ].max
  end

  def call
    scope = filtered
    total = scope.distinct.count(GROUP_KEY)
    keys = scope.group(GROUP_KEY).order(Arel.sql("MAX(audit_logs.created_at) DESC, MAX(audit_logs.id) DESC"))
                .limit(PER_PAGE).offset((@page - 1) * PER_PAGE).pluck(GROUP_KEY)
    logs = scope.where("COALESCE(audit_logs.request_id, audit_logs.id::text) IN (?)", keys.presence || [ "" ]).newest_first.to_a
    events = logs.group_by { |log| log.request_id || log.id.to_s }.map do |key, group|
      Event.new(key: key, user_id: group.first.user_id, user_name: group.first.user_name, at: group.map(&:created_at).max,
                ip_address: group.first.ip_address, logs: group.sort_by(&:id))
    end.sort_by { |event| [ keys.index(event.key) ] }
    Result.new(events: events, total: total, page: @page, pages: [ (total / PER_PAGE.to_f).ceil, 1 ].max)
  end

  private

  def filtered
    scope = AuditLog.all
    scope = scope.where(user_id: @filters[:user_id]) if @filters[:user_id].present?
    scope = scope.where(auditable_type: @filters[:type]) if @filters[:type].present?
    scope = scope.where(auditable_id: @filters[:id]) if @filters[:id].present?
    scope = scope.where("audit_logs.auditable_label ILIKE ?", "%#{AuditLog.sanitize_sql_like(@filters[:q].to_s.strip)}%") if @filters[:q].present?
    scope = scope.where(created_at: @filters[:from].beginning_of_day..) if @filters[:from]
    scope = scope.where(created_at: ..@filters[:to].end_of_day) if @filters[:to]
    scope
  end
end
