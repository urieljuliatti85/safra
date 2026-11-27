require "test_helper"

class PurchasePlannerTest < ActiveSupport::TestCase
  test "kg in natura = kg processado x fator" do
    need = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    expected_kg = need.breakdown.sum do |b|
      b.product.raw? ? b.quantity : b.quantity * b.product.raw_material.multiply_factor
    end
    assert_in_delta expected_kg, need.kg, 0.0001
  end

  test "caixa inteira arredonda para cima a parte de cada produto e soma (R3.9)" do
    need = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    per_package = need.raw_material.kg_per_package
    expected = need.breakdown.group_by(&:product).sum do |product, lines|
      (lines.sum { |b| b.quantity * product.raw_material.multiply_factor } / per_package).ceil
    end
    assert_equal expected, need.packages
    assert_equal 0, need.loose_kg
    assert_in_delta need.net_kg / per_package, need.net_packages, 0.01
  end

  test "fração soma o kg exato e compra as caixas inteiras e o resto em kg (R3.9)" do
    ActsAsTenant.with_tenant(company) { Product.where(raw_material: RawMaterial.find_by!(code: "cenoura")).update_all(rounding: :fraction) }
    need = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    per_package = need.raw_material.kg_per_package
    assert_equal (need.net_kg / per_package).floor, need.packages
    assert_in_delta need.net_kg - need.packages * per_package, need.loose_kg, 0.001
    assert_equal "#{need.packages} cx e #{Formatting.qty(need.loose_kg)} kg", Formatting.need_text(need)
  end

  test "caixa inteira e fração na mesma matéria-prima: as caixas de um somam com as frações do outro" do
    need = ActsAsTenant.with_tenant(company) do
      breakdown = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg").breakdown
      breakdown.map(&:product).uniq.first.update!(rounding: :fraction)
      PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    end
    per_package = need.raw_material.kg_per_package
    parts = need.breakdown.group_by(&:product).to_h { |product, lines| [ product, lines.sum { |b| b.quantity * product.raw_material.multiply_factor } ] }
    fraction_kg = parts.select { |product, _| product.fraction_rounding? }.values.sum
    whole = parts.reject { |product, _| product.fraction_rounding? }.values.sum { |kg| (kg / per_package).ceil }
    assert_equal whole + (fraction_kg / per_package).floor, need.packages
    assert_in_delta fraction_kg % per_package, need.loose_kg, 0.001
  end

  test "fração menor que uma caixa sai só em kg" do
    need = PurchasePlanner::Need.new(raw_material: Struct.new(:purchase_package).new("cx"), unit: "kg", processed_quantity: 0, raw_quantity: 0, ready: {},
                                     kg: 5, stock_kg: 0, net_kg: 5, packages: 0, loose_kg: 5.to_d, loose_units: 0, net_packages: 0.25, missing_factor: false, breakdown: [])
    assert_equal "5 kg", Formatting.need_text(need)
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

  # Saldo informado (esteira): a contagem vale só para a compra seguinte a ela. A sobra não passa para a outra compra.
  test "o que sobra depois de abater não passa para a compra seguinte" do
    need_13 = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg").kg
    count("cenoura", Date.new(2026, 10, 12), need_13 + 5)
    assert_equal need_13, stock_for("cenoura", Date.new(2026, 10, 13))
    assert_equal 0, stock_for("cenoura", Date.new(2026, 10, 15))
  end

  test "contagem feita antes da compra anterior não vale para a seguinte" do
    count("cenoura", Date.new(2026, 10, 12), 1000)
    count("cenoura", Date.new(2026, 10, 14), 4)
    assert_equal 4, stock_for("cenoura", Date.new(2026, 10, 15))
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
