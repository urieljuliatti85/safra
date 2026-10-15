require "test_helper"

class PurchasePlannerTest < ActiveSupport::TestCase
  test "kg in natura = kg processado x fator e embalagens = ROUND(kg / kg por embalagem)" do
    result = PurchasePlanner.new(company: company).call
    need = result.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    expected_kg = need.breakdown.sum do |b|
      b.product.raw? ? b.quantity : b.quantity * b.product.raw_material.multiply_factor
    end
    assert_in_delta expected_kg, need.kg, 0.0001
    assert_equal [ 1, (need.net_kg / 20).round ].max, need.packages
  end

  test "matéria-prima sem fator gera alerta, não erro" do
    result = PurchasePlanner.new(company: company).call
    cebola = result.purchases.values.flatten.find { |n| n.raw_material.code == "cebola" && n.processed_quantity.positive? }
    assert_not_nil cebola
    assert cebola.missing_factor
  end

  test "estoque da câmara fria é abatido da compra" do
    ActsAsTenant.with_tenant(company) do
      StockCount.create!(raw_material: RawMaterial.find_by!(code: "cenoura"), date: Date.new(2026, 10, 12), kg: 10)
    end
    need = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    assert_equal 10, need.stock_kg
    assert_equal need.kg - 10, need.net_kg
  end

  test "linhas cuja produção cai antes da primeira compra ficam listadas, não somem" do
    result = PurchasePlanner.new(company: company).call
    assert result.uncovered.all? { |line| line.product.production_date_for(line.delivery_date) < Date.new(2026, 10, 13) }
  end
end
