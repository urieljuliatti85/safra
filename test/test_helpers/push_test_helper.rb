# Liga os avisos com chaves de mentira e troca a entrega real por uma lista, sem rede e sem mocks.
module PushTestHelper
  # Chaves do aparelho no formato que o navegador entrega: ponto EC de 65 bytes e segredo de 16 (base64 url-safe).
  VALID_P256DH = Base64.urlsafe_encode64("\x04" + "k" * 64, padding: false).freeze
  VALID_AUTH = Base64.urlsafe_encode64("a" * 16, padding: false).freeze

  ENV_KEYS = { "VAPID_PUBLIC_KEY" => "chave-publica", "VAPID_PRIVATE_KEY" => "chave-privada", "VAPID_SUBJECT" => "mailto:teste@safra.local" }.freeze

  # Devolve a lista de [inscrição, aviso] entregues dentro do bloco. result: o que a entrega responde (:ok, :gone, :error).
  def with_push(result: :ok)
    deliveries = []
    original = PushSender.method(:deliver)
    PushSender.define_singleton_method(:deliver) { |subscription, payload| deliveries << [ subscription, payload ]; result }
    saved = ENV_KEYS.keys.to_h { |key| [ key, ENV[key] ] }
    ENV_KEYS.each { |key, value| ENV[key] = value }
    yield deliveries
    deliveries
  ensure
    PushSender.define_singleton_method(:deliver, original) if original
    saved&.each { |key, value| ENV[key] = value }
  end

  def subscribe(user, sectors:, endpoint: "https://fcm.googleapis.com/fcm/send/#{SecureRandom.hex(4)}")
    ActsAsTenant.with_tenant(user.company) do
      PushSubscription.create!(user: user, endpoint: endpoint, p256dh: VALID_P256DH, auth: VALID_AUTH, sectors: sectors)
    end
  end
end
