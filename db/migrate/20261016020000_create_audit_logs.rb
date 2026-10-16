class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    # Registro imutável de quem alterou o quê. Só o app grava (nunca há tela de edição ou exclusão).
    create_table :audit_logs do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :user_name, null: false          # nome na hora do evento: continua legível se a pessoa mudar
      t.string :action, null: false             # create, update, destroy, login, logout, login_failed, password_changed
      t.string :auditable_type
      t.bigint :auditable_id
      t.string :auditable_label                 # como o registro se chamava na hora (vale mesmo depois de excluído)
      t.jsonb :details, null: false, default: {} # { "Fator" => ["1,35", "1,4"] }
      t.string :request_id                      # agrupa o que veio de uma mesma ação (ex.: salvar tudo)
      t.string :ip_address
      t.datetime :created_at, null: false
      t.index [ :company_id, :created_at ]
      t.index [ :auditable_type, :auditable_id ]
      t.index :request_id
    end
  end
end
