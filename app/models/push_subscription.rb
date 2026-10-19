# Um aparelho inscrito nos avisos de produção. `sectors` são os setores (e "aprontes") que a pessoa escolheu acompanhar.
# Sem auditoria: o endpoint é do navegador, não interessa ao histórico.
class PushSubscription < ApplicationRecord
  SECTORS = (Cut::SECTORS + [ ProductionPlanner::APRONTES ]).freeze

  acts_as_tenant :company
  belongs_to :user

  validates :endpoint, :p256dh, :auth, presence: true
  validates :endpoint, uniqueness: true
  validate :sectors_are_known
  validate :keys_are_well_formed

  private

  # O navegador entrega p256dh (ponto EC de 65 bytes) e auth (16 bytes) em base64 url-safe; outra coisa nunca vai cifrar.
  def keys_are_well_formed
    errors.add(:p256dh, "inválida") unless decoded_size(p256dh) == 65
    errors.add(:auth, "inválida") unless decoded_size(auth) == 16
  end

  def decoded_size(value)
    Base64.urlsafe_decode64(value.to_s).bytesize
  rescue ArgumentError
    nil
  end

  def sectors_are_known
    errors.add(:sectors, "escolha ao menos um setor") if sectors.blank?
    errors.add(:sectors, "inclui setor desconhecido") unless (sectors - SECTORS).empty?
  end
end
