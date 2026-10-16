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

  # --- estoque da câmara fria entre compras ---

  def stock_for(code, date, unit = "kg")
    PurchasePlanner.new(company: company).call.need_for(date, code, unit)&.stock_kg
  end

  def count(code, date, kg)
    ActsAsTenant.with_tenant(company) { StockCount.create!(raw_material: RawMaterial.find_by!(code: code), date: date, kg: kg) }
  end

  test "contagem entre duas compras vale para a segunda, não para a primeira" do
    count("cenoura", Date.new(2026, 10, 14), 30)
    assert_equal 0, stock_for("cenoura", Date.new(2026, 10, 13))
    assert_equal 30, stock_for("cenoura", Date.new(2026, 10, 15))
  end

  test "o que sobra depois de abater vai para a compra seguinte" do
    need_13 = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg").kg
    need_15 = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 15), "cenoura", "kg").kg
    count("cenoura", Date.new(2026, 10, 12), need_13 + 5)
    assert_equal need_13, stock_for("cenoura", Date.new(2026, 10, 13))
    assert_equal [ 5, need_15 ].min, stock_for("cenoura", Date.new(2026, 10, 15))
  end

  test "contagem nova substitui a sobra da anterior" do
    count("cenoura", Date.new(2026, 10, 12), 1000)
    count("cenoura", Date.new(2026, 10, 14), 4)
    assert_equal 4, stock_for("cenoura", Date.new(2026, 10, 15))
  end

  test "contagem zero (câmara vazia) zera a sobra" do
    count("cenoura", Date.new(2026, 10, 12), 1000)
    count("cenoura", Date.new(2026, 10, 14), 0)
    assert_equal 0, stock_for("cenoura", Date.new(2026, 10, 15))
  end

  test "contagem depois da última compra não abate nada" do
    count("cenoura", Date.new(2026, 10, 20), 1000)
    todas = PurchasePlanner.new(company: company).call.purchases.values.flatten
    assert_not_empty todas
    assert todas.all? { |n| n.stock_kg.zero? }
  end

  test "só abate o que é pedido em kg" do
    count("ovos", Date.new(2026, 10, 12), 100) # ovos são pedidos em caixa
    ovos = PurchasePlanner.new(company: company).call.purchases.values.flatten.select { |n| n.raw_material.code == "ovos" }
    assert ovos.all? { |n| n.stock_kg.zero? }
  end

  test "estoque maior que a necessidade zera a compra líquida" do
    count("cenoura", Date.new(2026, 10, 12), 100_000)
    need = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    assert_equal 0, need.net_kg
    assert_equal 0, need.packages
  end
end
