require "test_helper"

class OrderWeekCopierTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @customer = Customer.find_by!(code: "hbp")
    @previous = Order.find_by!(customer: @customer, week_start: Date.new(2026, 10, 12))
    @order = Order.create!(customer: @customer, week_start: Date.new(2026, 10, 19))
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def quantities(order)
    order.lines.reload.group(:product_id, :unit, :delivery_date).sum(:quantity).select { |_, q| q.positive? }
  end

  test "copia a semana anterior com as entregas 7 dias depois e grava a versão" do
    expected = quantities(@previous).transform_keys { |product_id, unit, date| [ product_id, unit, date + 7 ] }

    result = OrderWeekCopier.new(order: @order).call

    assert result.ok?, result.errors.inspect
    assert_equal expected, quantities(@order)
    assert_equal [ [ 1, "copy" ] ], @order.versions.pluck(:version, :source)
    assert_equal "Copiado da semana anterior", @order.versions.first.source_label
  end

  test "não copia para semana que já tem pedido" do
    product = Product.find_by!(code: "cenoura_cubinhos")
    @order.lines.create!(product: product, unit: "kg", delivery_date: Date.new(2026, 10, 20), quantity: 4)

    result = OrderWeekCopier.new(order: @order).call

    assert_not result.ok?
    assert_match "já tem pedido", result.errors.first
    assert_equal({ [ product.id, "kg", Date.new(2026, 10, 20) ] => 4 }, quantities(@order))
  end

  test "semana anterior sem pedido não copia nada" do
    order = Order.create!(customer: @customer, week_start: Date.new(2026, 11, 2))
    copier = OrderWeekCopier.new(order: order)

    assert_equal 0, copier.previous_lines_count
    assert_not copier.call.ok?
    assert_empty order.lines.reload
  end
end
