# Histórico de envios aos setores: cada versão guarda quem enviou. As versões já enviadas pegam o autor do histórico geral.
class AddSentByToProductionPlans < ActiveRecord::Migration[8.1]
  def up
    add_reference :production_plans, :sent_by, foreign_key: { to_table: :users }
    execute <<~SQL
      UPDATE production_plans SET sent_by_id = audit_logs.user_id
      FROM audit_logs
      WHERE audit_logs.auditable_type = 'ProductionPlan' AND audit_logs.auditable_id = production_plans.id
        AND audit_logs.action = 'create' AND audit_logs.user_id IS NOT NULL
    SQL
  end

  def down
    remove_reference :production_plans, :sent_by
  end
end
