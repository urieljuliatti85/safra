# Quem alterou o quê. Imutável: o app só cria registros; nunca edita nem apaga.
class AuditLog < ApplicationRecord
  ACTIONS = %w[create update destroy login logout login_failed password_changed].freeze

  acts_as_tenant :company

  belongs_to :user, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :user_name, presence: true

  before_update { raise ActiveRecord::ReadOnlyRecord, "O histórico não pode ser alterado." }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "O histórico não pode ser apagado." }

  # Eventos que não são mudança de cadastro: entrar, sair, senha. O app passa o usuário e a requisição.
  def self.record_event(action, user:, request:, label: nil, details: {})
    ActsAsTenant.with_tenant(user.company) do
      create!(company: user.company, user: user, user_name: user.name, action: action, auditable_type: "User", auditable_id: user.id,
              auditable_label: label || user.name, details: details, request_id: request.request_id, ip_address: request.remote_ip)
    end
  end

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
end
