# Entrega um aviso (Web Push) a um aparelho. Só funciona com as três chaves VAPID nas variáveis de ambiente:
# VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY e VAPID_SUBJECT (mailto: de quem responde pelo sistema).
# Gerar o par de chaves: ruby -e 'require "web-push"; k = WebPush.generate_key; puts k.public_key, k.private_key'
class PushSender
  TTL = 6.hours.to_i

  def self.enabled?
    %w[VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY VAPID_SUBJECT].all? { |name| ENV[name].present? }
  end

  def self.public_key = ENV["VAPID_PUBLIC_KEY"]

  # :ok, :gone (aparelho cancelou ou a inscrição venceu: pode apagar) ou :error (tenta de novo no próximo envio).
  def self.deliver(subscription, payload)
    WebPush.payload_send(
      message: payload.to_json, endpoint: subscription.endpoint, p256dh: subscription.p256dh, auth: subscription.auth,
      ttl: TTL, urgency: "high",
      vapid: { subject: ENV["VAPID_SUBJECT"], public_key: ENV["VAPID_PUBLIC_KEY"], private_key: ENV["VAPID_PRIVATE_KEY"] }
    )
    :ok
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    :gone
  rescue WebPush::ResponseError, SocketError, Timeout::Error, SystemCallError, OpenSSL::OpenSSLError => error
    Rails.logger.warn("Aviso não entregue (#{error.class}): #{error.message.to_s.truncate(200)}")
    :error
  end
end
