# Chave de acesso da API de uma empresa. Criada pelo administrador; o token aparece uma única vez, na criação.
# Só o hash fica no banco. "read" lê; "write" também grava pedidos e contagens de estoque.
class ApiToken < ApplicationRecord
  SCOPES = %w[read write].freeze
  SCOPE_LABELS = { "read" => "Só leitura", "write" => "Leitura e escrita" }.freeze
  PREFIX = "safra_".freeze

  acts_as_tenant :company
  include Auditable
  audited except: %w[token_digest token_prefix last_used_at]

  belongs_to :company

  validates :name, presence: true, length: { maximum: 80 }
  validates :scope, inclusion: { in: SCOPES }

  scope :active, -> { where(revoked_at: nil) }

  def audit_label = "#{name} (#{token_prefix}…)"

  # Cria a chave e devolve [registro, token em texto]; o texto não pode ser recuperado depois.
  def self.issue!(company:, name:, scope:)
    plain = "#{PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    token = ActsAsTenant.with_tenant(company) do
      create!(company: company, name: name, scope: scope, token_digest: digest(plain), token_prefix: plain.first(PREFIX.size + 4))
    end
    [ token, plain ]
  end

  # Acha a chave ativa pelo texto recebido. Roda sem empresa: é a chave que diz de qual empresa se trata.
  def self.authenticate(plain)
    return nil if plain.blank?

    ActsAsTenant.without_tenant { active.includes(:company).find_by(token_digest: digest(plain)) }
  end

  def self.digest(plain) = Digest::SHA256.hexdigest(plain.to_s)

  def write? = scope == "write"
  def revoked? = revoked_at.present?
  def scope_label = SCOPE_LABELS.fetch(scope)

  def revoke!
    update!(revoked_at: Time.current)
  end

  def touch_usage!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 5.minutes.ago
  end
end
