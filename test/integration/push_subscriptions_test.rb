require "test_helper"

class PushSubscriptionsTest < ActionDispatch::IntegrationTest
  KEYS = { p256dh: PushTestHelper::VALID_P256DH, auth: PushTestHelper::VALID_AUTH }.freeze

  def subscribe_params(endpoint, sectors)
    { endpoint: endpoint, keys: KEYS, sectors: sectors }
  end

  test "produção ativa os avisos do aparelho com os setores escolhidos" do
    sign_in_as(user_for(:production))
    post push_subscription_path, params: subscribe_params("https://fcm.googleapis.com/fcm/send/a", %w[ralpic aprontes]), as: :json
    assert_response :success
    assert_equal %w[ralpic aprontes], response.parsed_body["sectors"]

    get push_subscription_path(endpoint: "https://fcm.googleapis.com/fcm/send/a"), as: :json
    assert_equal %w[ralpic aprontes], response.parsed_body["sectors"]

    post push_subscription_path, params: subscribe_params("https://fcm.googleapis.com/fcm/send/a", %w[palito]), as: :json
    assert_equal 1, ActsAsTenant.with_tenant(company) { PushSubscription.where(endpoint: "https://fcm.googleapis.com/fcm/send/a").count }
    get push_subscription_path(endpoint: "https://fcm.googleapis.com/fcm/send/a"), as: :json
    assert_equal %w[palito], response.parsed_body["sectors"]
  end

  test "sem setor ou com setor desconhecido não grava" do
    sign_in_as(user_for(:production))
    post push_subscription_path, params: subscribe_params("https://fcm.googleapis.com/fcm/send/b", []), as: :json
    assert_response :unprocessable_entity
    post push_subscription_path, params: subscribe_params("https://fcm.googleapis.com/fcm/send/b", %w[lixo]), as: :json
    assert_response :unprocessable_entity
    assert_equal 0, ActsAsTenant.with_tenant(company) { PushSubscription.count }
  end

  # SSRF: o servidor faz POST no endpoint; só serviços de push dos navegadores.
  test "endpoint fora dos serviços de push não grava" do
    sign_in_as(user_for(:production))
    [ "http://169.254.169.254/latest/meta-data", "https://localhost/push", "http://fcm.googleapis.com/fcm/send/x",
      "https://fcm.googleapis.com:8443/fcm/send/x", "https://fcm.googleapis.com.evil.example/x", "https://user@fcm.googleapis.com/x",
      "https://10.0.0.5/push", "nada" ].each do |endpoint|
      post push_subscription_path, params: subscribe_params(endpoint, %w[ralpic]), as: :json
      assert_response :unprocessable_entity, endpoint
    end
    assert_equal 0, ActsAsTenant.with_tenant(company) { PushSubscription.count }

    %w[https://updates.push.services.mozilla.com/wpush/v2/x https://wns2-bl2p.notify.windows.com/w/?token=x
       https://web.push.apple.com/QGx].each do |endpoint|
      post push_subscription_path, params: subscribe_params(endpoint, %w[ralpic]), as: :json
      assert_response :success, endpoint
    end
  end

  test "chaves do aparelho malformadas não gravam" do
    sign_in_as(user_for(:production))
    post push_subscription_path, params: { endpoint: "https://fcm.googleapis.com/fcm/send/d", keys: { p256dh: "abc", auth: "def" }, sectors: %w[ralpic] }, as: :json
    assert_response :unprocessable_entity
    assert_equal 0, ActsAsTenant.with_tenant(company) { PushSubscription.count }
  end

  test "desativar apaga só o aparelho da própria pessoa" do
    mine = subscribe(user_for(:production), sectors: %w[ralpic], endpoint: "https://fcm.googleapis.com/fcm/send/mine")
    theirs = subscribe(user_for(:office), sectors: %w[ralpic], endpoint: "https://fcm.googleapis.com/fcm/send/theirs")
    sign_in_as(user_for(:production))

    delete push_subscription_path(endpoint: theirs.endpoint), as: :json
    assert ActsAsTenant.with_tenant(company) { PushSubscription.exists?(theirs.id) }
    get push_subscription_path(endpoint: theirs.endpoint), as: :json
    assert_response :not_found

    delete push_subscription_path(endpoint: mine.endpoint), as: :json
    assert_response :no_content
    assert_not ActsAsTenant.with_tenant(company) { PushSubscription.exists?(mine.id) }
  end

  test "aparelho compartilhado passa para quem ativou por último" do
    subscribe(user_for(:office), sectors: %w[ralpic], endpoint: "https://fcm.googleapis.com/fcm/send/shared")
    sign_in_as(user_for(:production))
    post push_subscription_path, params: subscribe_params("https://fcm.googleapis.com/fcm/send/shared", %w[palito]), as: :json
    assert_response :success
    owner = ActsAsTenant.with_tenant(company) { PushSubscription.find_by!(endpoint: "https://fcm.googleapis.com/fcm/send/shared").user }
    assert_equal user_for(:production), owner
  end

  test "sem login não ativa" do
    post push_subscription_path, params: subscribe_params("https://fcm.googleapis.com/fcm/send/c", %w[ralpic]), as: :json
    assert_response :redirect
    assert_equal 0, ActsAsTenant.with_tenant(company) { PushSubscription.count }
  end

  test "painel de avisos só aparece com as chaves configuradas" do
    sign_in_as(user_for(:production))
    get production_path(date: "2026-10-13")
    assert_select "#avisos", count: 0
    with_push do
      get production_path(date: "2026-10-13")
      assert_select "#avisos[data-push-key-value='chave-publica']"
      assert_select "#avisos input[type=checkbox]", 7
    end
  end

  test "enviar aos setores coloca o aviso na fila" do
    sign_in_as(user_for(:office))
    assert_enqueued_with(job: SendProductionVersionPushJob) do
      post publish_production_path(date: "2026-10-13")
    end
  end

  test "manifesto e service worker abrem sem login" do
    get pwa_manifest_path(format: :json)
    assert_response :success
    assert_equal "Safra", response.parsed_body["name"]
    get pwa_service_worker_path(format: :js)
    assert_response :success
    assert_match "showNotification", response.body
    assert_match "javascript", response.media_type
  end
end
