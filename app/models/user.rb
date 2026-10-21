# Pessoa que entra no sistema. Não usa acts_as_tenant: o login precisa achar o usuário antes de saber a empresa.
class User < ApplicationRecord
  ROLES = %w[admin office production].freeze
  ROLE_LABELS = { "admin" => "Administrador", "office" => "Escritório", "production" => "Produção" }.freeze

  has_secure_password
  include Auditable
  audited except: %w[must_change_password tour_seen_at]

  def audit_label = "#{name} (#{email_address})"
  has_many :sessions, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  belongs_to :company

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :password, length: { minimum: 8 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :admins, -> { where(role: "admin") }

  ROLES.each do |role|
    define_method(:"#{role}?") { self.role == role }
  end

  # Senha provisória legível (sem 0, O, I, l, 1), mostrada uma vez ao administrador.
  def self.generate_provisional_password
    SecureRandom.alphanumeric(10).tr("0OIl1", "abcde")
  end

  def role_label
    ROLE_LABELS.fetch(role)
  end

  # Gera uma senha provisória legível, grava e devolve para o admin repassar uma única vez.
  def reset_to_provisional_password!
    provisional = User.generate_provisional_password
    update!(password: provisional, password_confirmation: provisional, must_change_password: true)
    sessions.destroy_all
    provisional
  end

  # Desativa sem apagar (o histórico continua apontando para a pessoa) e derruba as sessões abertas.
  def deactivate!
    update!(active: false)
    sessions.destroy_all
  end
end
