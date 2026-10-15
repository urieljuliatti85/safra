require "test_helper"

class OrderGridSaverTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @order = Order.find_by!(customer: Customer.find_by!(code: "hbp"), week_start: Date.new(2026, 10, 12))
    @product = Product.find_by!(code: "cenoura_cubinhos")
    @key = "#{@product.id}|kg"
  end

  teardown { ActsAsTenant.current_tenant = nil }

  test "altera quantidade existente e informa os dias alterados" do
    result = OrderGridSaver.new(order: @order, quantities: { @key => { "2026-10-12" => "11,5" } }).call
    assert result.ok?
    assert_equal [ Date.new(2026, 10, 12) ], result.changed_dates
    assert_equal 11.5, @order.lines.where(product: @product, delivery_date: "2026-10-12").sum(:quantity)
  end

  test "quantidade vazia apaga a linha e nova quantidade cria" do
    OrderGridSaver.new(order: @order, quantities: { @key => { "2026-10-12" => "", "2026-10-19" => "3" } }).call
    assert_equal 0, @order.lines.where(product: @product, delivery_date: "2026-10-12").count
    assert_equal 3, @order.lines.where(product: @product, delivery_date: "2026-10-19").sum(:quantity)
  end

  test "texto que não é número rejeita tudo e não grava nada" do
    before = @order.lines.count
    result = OrderGridSaver.new(order: @order, quantities: { @key => { "2026-10-12" => "5 + 2", "2026-10-13" => "9" } }).call
    assert_not result.ok?
    assert_match "não é um número", result.errors.first
    assert_equal before, @order.lines.count
    assert_equal 8, @order.lines.where(product: @product, delivery_date: "2026-10-13").sum(:quantity)
  end

  test "valor sem alteração não conta como mudança" do
    result = OrderGridSaver.new(order: @order, quantities: { @key => { "2026-10-12" => "10" } }).call
    assert_empty result.changed_dates
  end
end
