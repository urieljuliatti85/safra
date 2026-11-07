require "test_helper"

# Medida pedida (R1.14, D12): vale para a linha inteira da grade e orienta o preparo, acima da referência do corte.
class OrderLineMeasureTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @order = Order.find_by!(customer: Customer.find_by!(code: "hbp"), week_start: Date.new(2026, 10, 12))
    @product = Product.find_by!(code: "cenoura_cubinhos")
    @key = "#{@product.id}|kg"
    @lines = -> { @order.lines.where(product: @product, unit: "kg") }
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def save(quantities: {}, measures: {})
    OrderGridSaver.new(order: @order, quantities: quantities, measures: measures).call
  end

  test "a medida vale para todos os dias da linha, inclusive dia novo, sem criar versão" do
    versions = @order.versions.count
    result = save(measures: { @key => " 8 × 8 mm " })

    assert result.measures_changed
    assert_empty result.changed_dates
    assert_equal versions, @order.versions.count
    assert_equal [ "8 × 8 mm" ], @lines.call.pluck(:measure).uniq

    save(quantities: { @key => { "2026-10-17" => "4" } }, measures: { @key => "8 × 8 mm" })
    assert_equal [ "8 × 8 mm" ], @lines.call.pluck(:measure).uniq
  end

  test "medida vazia apaga; a mesma medida não conta como mudança" do
    save(measures: { @key => "8 × 8 mm" })
    assert_not save(measures: { @key => "8 × 8 mm" }).measures_changed
    assert save(measures: { @key => "" }).measures_changed
    assert_equal [ nil ], @lines.call.pluck(:measure).uniq
  end
end
