require "test_helper"

# Pesagem (R2.6, R2.7; esteira simplificada, passo 5): checklist da entrega por cliente, com o peso real em kg ao lado da
# quantidade e da unidade do pedido. Exemplo da R2.6: 100 mamões pesam 40 kg; 1 melancia, 12 kg.
class WeighingTest < ActionDispatch::IntegrationTest
  DELIVERY = Date.new(2026, 12, 14)

  setup do
    ActsAsTenant.current_tenant = company
    @customer = Customer.order(:name).first
    @order = Order.create!(customer: @customer, week_start: DELIVERY.beginning_of_week)
    @mamao = @order.lines.create!(product: fruit("Mamão"), delivery_date: DELIVERY, quantity: 100, unit: "un")
    @melancia = @order.lines.create!(product: fruit("Melancia"), delivery_date: DELIVERY, quantity: 1, unit: "un")
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def fruit(name)
    Product.find_by!(name: name)
  end

  test "o checklist mostra cada cliente com o pedido e o campo de peso real" do
    sign_in_as(user_for(:production))
    get weighing_path(date: DELIVERY)
    assert_response :success
    assert_select "h1", "Pesagem"
    assert_select "h2", @customer.name
    assert_select "td[data-label='Pedido']", text: "100 un"
    assert_select "input[name='weights[#{@mamao.id}]']"
    assert_select "[data-weighing-total]", /0 de 2 pesados/
    assert_select "nav[aria-label='Principal'] a", text: "Pesagem"
  end

  test "o peso real fica ao lado do pedido, e o total sai quando todos foram pesados" do
    sign_in_as(user_for(:production))
    patch weighing_path, params: { date: DELIVERY, weights: { @mamao.id => "40" } }
    assert_redirected_to weighing_path(date: DELIVERY)
    follow_redirect!
    assert_match "1 peso salvo na entrega de 14/12", response.body
    assert_select "[data-weighing-total]", /1 de 2 pesados/
    assert_equal 40, @mamao.reload.actual_kg
    assert_equal [ 100, "un" ], [ @mamao.quantity, @mamao.unit ]

    patch weighing_path, params: { date: DELIVERY, weights: { @mamao.id => "40", @melancia.id => "12,5" } }
    follow_redirect!
    assert_match "1 peso salvo", response.body
    assert_select "[data-weighing-total]", /Total pesado: 52,5 kg/
  end

  test "campo vazio volta para não pesado, e zero é pesado" do
    sign_in_as(user_for(:office))
    @mamao.update!(actual_kg: 40)
    patch weighing_path, params: { date: DELIVERY, weights: { @mamao.id => "40" } }
    follow_redirect!
    assert_match "Nada mudou", response.body

    patch weighing_path, params: { date: DELIVERY, weights: { @mamao.id => "0" } }
    assert_equal 0, @mamao.reload.actual_kg

    patch weighing_path, params: { date: DELIVERY, weights: { @mamao.id => "" } }
    assert_nil @mamao.reload.actual_kg
  end

  test "valor inválido não salva nada e mostra o que foi digitado" do
    sign_in_as(user_for(:office))
    patch weighing_path, params: { date: DELIVERY, weights: { @mamao.id => "40", @melancia.id => "muito" } }
    assert_response :unprocessable_entity
    assert_match "Melancia", response.body
    assert_select "input[name='weights[#{@melancia.id}]'][value='muito']"
    assert_nil @mamao.reload.actual_kg

    patch weighing_path, params: { date: DELIVERY, weights: { @mamao.id => "-1" } }
    assert_response :unprocessable_entity
    assert_nil @mamao.reload.actual_kg
  end

  test "linha de outra entrega não é gravada" do
    sign_in_as(user_for(:office))
    other_day = @order.lines.create!(product: fruit("Mamão"), delivery_date: DELIVERY + 1, quantity: 10, unit: "un")
    patch weighing_path, params: { date: DELIVERY, weights: { other_day.id => "5" } }
    follow_redirect!
    assert_match "Nada mudou", response.body
    assert_nil other_day.reload.actual_kg
  end

  test "a alteração do pedido na grade mantém o peso já anotado" do
    @mamao.update!(actual_kg: 40)
    key = "#{@mamao.product_id}|un"
    result = OrderGridSaver.new(order: @order, quantities: { key => { DELIVERY.iso8601 => "120" } }, late_confirmed: true).call
    assert result.ok?, result.errors.inspect
    assert_equal [ 120, 40 ], [ @mamao.reload.quantity, @mamao.actual_kg ]
  end
end
