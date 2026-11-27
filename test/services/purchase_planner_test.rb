require "test_helper"

class PurchasePlannerTest < ActiveSupport::TestCase
  test "kg in natura = kg processado x fator" do
    need = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    expected_kg = need.breakdown.sum do |b|
      b.product.raw? ? b.quantity : b.quantity * b.product.raw_material.multiply_factor
    end
    assert_in_delta expected_kg, need.kg, 0.0001
  end

  test "matéria-prima sem fator gera alerta, não erro" do
    result = PurchasePlanner.new(company: company).call
    cebola = result.purchases.values.flatten.find { |n| n.raw_material.code == "cebola" && n.processed_quantity.positive? }
    assert_not_nil cebola
    assert cebola.missing_factor
  end

  test "linhas cuja produção (véspera da entrega) cai antes da primeira compra ficam listadas, não somem" do
    result = PurchasePlanner.new(company: company).call
    assert result.uncovered.all? { |line| line.delivery_date - 1 < Date.new(2026, 10, 13) }
  end

  # Cada compra abastece a produção do dia dela até a véspera da compra seguinte, pelo dia de execução (a véspera da
  # entrega ou, no preparo no dia, R3.7, o próprio dia da entrega).
  test "a compra de segunda cobre as entregas de terça a quinta, e a de quinta as de sexta em diante" do
    result = PurchasePlanner.new(company: company).call
    on_13 = result.purchases.fetch(Date.new(2026, 10, 13)).flat_map(&:breakdown)
    on_15 = result.purchases.fetch(Date.new(2026, 10, 15)).flat_map(&:breakdown)
    assert on_13.all? { |b| b.production_date >= Date.new(2026, 10, 13) && b.production_date < Date.new(2026, 10, 15) }
    assert on_15.all? { |b| b.production_date >= Date.new(2026, 10, 15) }
    assert_includes on_13.map { |b| [ b.product.code, b.delivery_date, b.production_date ] },
                    [ "alface_picada", Date.new(2026, 10, 13), Date.new(2026, 10, 13) ], "preparo no dia: executa e compra pelo dia da entrega"
  end

  test "estoque contado não abate a compra (MVP: volume total)" do
    ActsAsTenant.with_tenant(company) do
      StockCount.create!(raw_material: RawMaterial.find_by!(code: "cenoura"), date: Date.new(2026, 10, 12), kg: 10)
    end
    need = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    assert_equal 0, need.stock_kg
    assert_equal need.kg, need.net_kg
    assert_nil need.packages
  end
end
