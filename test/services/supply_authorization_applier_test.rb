require "test_helper"

# AF da Nutrir (R1.27, D4), com o exemplo real: AF 0009100649, entrega 06/11/2026, vagem cubinho de 95 para 120 kg.
class SupplyAuthorizationApplierTest < ActiveSupport::TestCase
  setup do
    # Antes das 48 h da entrega (R1.26, D8): estes testes não são sobre o prazo de alteração.
    travel_to Time.zone.local(2026, 10, 28, 9)
    ActsAsTenant.current_tenant = company
    @nutrir = Customer.find_by!(code: "nutrir")
    @vagem = Product.find_by!(code: "vagem_cubinhos")
    @cenoura = Product.find_by!(code: "cenoura_cubos")
    @date = Date.new(2026, 11, 6)
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def apply(items)
    SupplyAuthorizationApplier.new(customer: @nutrir, number: "0009100649", delivery_date: @date,
                                   items: items.map { |product, quantity| { product: product, unit: "kg", quantity: quantity } }).call
  end

  def lines = Order.find_by!(customer: @nutrir, week_start: Date.new(2026, 11, 2)).lines.reload

  test "a alteração é a mesma AF: troca a quantidade, mantém o número e grava uma versão nova" do
    assert apply([ [ @vagem, 95 ], [ @cenoura, 30 ] ]).ok?
    assert apply([ [ @vagem, 120 ], [ @cenoura, 30 ] ]).ok?

    vagem = lines.find_by!(product: @vagem)
    assert_equal [ 120, "0009100649", @date ], [ vagem.quantity, vagem.af_number, vagem.delivery_date ]
    order = lines.first.order
    assert_equal [ "import" ], order.versions.order(:version).last(1).map(&:source)
    assert_equal [ [ "Vagem em cubinhos", "95", "120" ] ], order.versions.order(:version).last.changes_list.map { |c| [ c["product"], c["before"], c["after"] ] }
  end

  test "produto que sumiu da AF alterada vai a zero; o resto do pedido não muda" do
    other = Order.find_or_create_by!(customer: @nutrir, week_start: Date.new(2026, 11, 2))
    other.lines.create!(product: @cenoura, unit: "kg", delivery_date: Date.new(2026, 11, 5), quantity: 17, af_number: "0009100648")
    apply([ [ @vagem, 95 ], [ @cenoura, 30 ] ])

    assert apply([ [ @vagem, 120 ] ]).ok?
    assert_equal [ [ "cenoura_cubos", Date.new(2026, 11, 5), 17 ], [ "vagem_cubinhos", @date, 120 ] ],
                 lines.includes(:product).map { |l| [ l.product.code, l.delivery_date, l.quantity.to_i ] }.sort_by(&:first)
  end

  test "o cliente mensal não segue o prazo da quinta-feira" do
    assert @nutrir.monthly_orders?
    order = Order.find_or_create_by!(customer: @nutrir, week_start: Date.new(2026, 11, 2))
    order.received_at = Time.zone.local(2026, 11, 1, 9)
    assert_not order.late?
  end
end
