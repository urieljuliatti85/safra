require "test_helper"

# O seed só cria o que falta: em produção, rodar db:seed de novo não pode desfazer cadastros editados na tela
# nem apagar pedidos já lançados.
class SeedsSafetyTest < ActiveSupport::TestCase
  setup { ActsAsTenant.current_tenant = company }
  teardown { ActsAsTenant.current_tenant = nil }

  test "rodar o seed de novo preserva cadastros editados e pedidos alterados" do
    cenoura = RawMaterial.find_by!(code: "cenoura")
    cenoura.update!(multiply_factor: 9.99, kg_per_package: 18)
    line = OrderLine.joins(order: :customer).find_by!(customers: { code: "hbp" }, delivery_date: "2026-10-13", unit: "kg")
    line.update!(quantity: 777)
    total = OrderLine.count

    load_seeds

    assert_equal [ 9.99, 18.0 ], cenoura.reload.then { |rm| [ rm.multiply_factor.to_f, rm.kg_per_package.to_f ] }
    assert_equal 777, line.reload.quantity
    assert_equal total, OrderLine.count
  end

  test "um cadastro apagado volta no seed, mas pedido apagado não volta" do
    Customer.create!(code: "extra", name: "Extra", short_name: "Extra")
    load_seeds
    assert_equal 6 + 1, Customer.count
    sr_order = Order.joins(:customer).find_by!(customers: { code: "hbp" })
    sr_order.lines.destroy_all
    load_seeds
    assert_equal 0, sr_order.lines.count
  end
end
