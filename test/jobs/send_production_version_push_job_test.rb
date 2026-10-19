require "test_helper"

class SendProductionVersionPushJobTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @date = Date.new(2026, 10, 13)
    @office = user_for(:office)
    @production = user_for(:production)
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def publish(user: @office)
    PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: @date).call, user: user)
  end

  def change_cenoura_ralada(by)
    OrderLine.joins(:product).find_by!(products: { code: "cenoura_ralada" }, delivery_date: @date).increment!(:quantity, by)
  end

  test "avisa só quem acompanha o setor que mudou" do
    publish
    ralados = subscribe(@production, sectors: %w[ralpic])
    palitos = subscribe(user_for(:admin), sectors: %w[palito])
    change_cenoura_ralada(4)
    plan = publish

    deliveries = with_push { SendProductionVersionPushJob.perform_now(plan.id) }

    assert_equal [ ralados ], deliveries.map(&:first)
    assert_equal "Cenoura ralada: 3 → 7 kg", deliveries.first.last[:options][:body]
    assert_not_includes deliveries.map(&:first), palitos
  end

  test "quem enviou a versão não recebe o próprio aviso" do
    own = subscribe(@office, sectors: PushSubscription::SECTORS)
    other = subscribe(@production, sectors: PushSubscription::SECTORS)
    deliveries = with_push { SendProductionVersionPushJob.perform_now(publish.id) }
    assert_equal [ other ], deliveries.map(&:first)
    assert_not_includes deliveries.map(&:first), own
  end

  test "usuário desativado não recebe" do
    subscribe(@production, sectors: PushSubscription::SECTORS)
    @production.update_columns(active: false)
    assert_empty with_push { SendProductionVersionPushJob.perform_now(publish.id) }
  end

  test "inscrição que o serviço de push recusou como vencida é apagada" do
    subscription = subscribe(@production, sectors: PushSubscription::SECTORS)
    with_push(result: :gone) { SendProductionVersionPushJob.perform_now(publish.id) }
    assert_not PushSubscription.exists?(subscription.id)
  end

  test "falha temporária mantém a inscrição" do
    subscription = subscribe(@production, sectors: PushSubscription::SECTORS)
    with_push(result: :error) { SendProductionVersionPushJob.perform_now(publish.id) }
    assert PushSubscription.exists?(subscription.id)
  end

  test "sem as chaves VAPID não envia nada" do
    subscribe(@production, sectors: PushSubscription::SECTORS)
    plan = publish
    deliveries = []
    original = PushSender.method(:deliver)
    PushSender.define_singleton_method(:deliver) { |*args| deliveries << args; :ok }
    saved = PushTestHelper::ENV_KEYS.keys.to_h { |key| [ key, ENV.delete(key) ] }
    SendProductionVersionPushJob.perform_now(plan.id)
    assert_empty deliveries
  ensure
    PushSender.define_singleton_method(:deliver, original)
    saved.each { |key, value| ENV[key] = value if value }
  end

  test "versão que não existe mais é ignorada" do
    with_push { |deliveries| SendProductionVersionPushJob.perform_now(0); assert_empty deliveries }
  end
end
