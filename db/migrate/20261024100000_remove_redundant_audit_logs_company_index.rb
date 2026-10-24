# O índice composto [company_id, created_at] já atende as buscas só por company_id.
class RemoveRedundantAuditLogsCompanyIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :audit_logs, :company_id, name: "index_audit_logs_on_company_id"
  end
end
