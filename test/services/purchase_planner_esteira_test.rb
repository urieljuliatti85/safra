require "test_helper"

# A conta da compra na ordem da esteira (R3.8, D39), com os números ilustrativos do próprio documento: pedido de 50 kg,
# 10 kg de produto pronto, fator 1,50, 15 kg de matéria-prima e caixa de 20 kg. A esteira dá 45 kg a comprar:
# 3 caixas inteiras ou 2 caixas e 5 kg (R3.9).
class PurchasePlannerEsteiraTest < ActiveSupport::TestCase
  DELIVERY = Date.new(2026, 10, 15)

  setup do
    ActsAsTenant.with_tenant(company) do
      @raw_material = RawMaterial.create!(name: "Vegetal da esteira", code: "vegetal_esteira", multiply_factor: 1.5, kg_per_package: 20,
                                          purchase_package: "cx", supplier: Supplier.first)
      @product = Product.create!(name: "Vegetal da esteira em cubos", code: "vegetal_esteira_cubos", product_group: "processed",
                                 raw_material: @raw_material, cut: Cut.find_by!(code: "cubos"), unit: "kg")
      Order.joins(:customer).find_by!(customers: { code: "hbp" }, week_start: Date.new(2026, 10, 12))
           .lines.create!(product: @product, delivery_date: DELIVERY, quantity: 50, unit: "kg")
      @purchase_date = PurchaseDay.where(date: ..@product.production_date_for(DELIVERY)).maximum(:date)
    end
  end

  def need = PurchasePlanner.new(company: company).call.need_for(@purchase_date, "vegetal_esteira", "kg")

  def count(ready: nil, raw: nil)
    ActsAsTenant.with_tenant(company) do
      ProductStockCount.create!(product: @product, date: @purchase_date, quantity: ready) if ready
      StockCount.create!(raw_material: @raw_material, date: @purchase_date, kg: raw) if raw
    end
  end

  test "pedido, menos produto pronto, vezes o fator, menos matéria-prima: 45 kg, 3 caixas inteiras" do
    count(ready: 10, raw: 15)
    assert_equal({ @product => 10 }, need.ready)
    assert_equal 60, need.kg
    assert_equal 15, need.stock_kg
    assert_equal 45, need.net_kg
    assert_equal 2.25, need.net_packages
    assert_equal 3, need.packages
    assert_equal "3 cx de 20 kg", Formatting.need_text(need)
  end

  test "o mesmo exemplo em fração: 2 caixas e 5 kg" do
    ActsAsTenant.with_tenant(company) { @product.update!(rounding: :fraction) }
    count(ready: 10, raw: 15)
    assert_equal "2 cx de 20 kg e 5 kg", Formatting.need_text(need)
  end

  test "sem produto pronto contado, o pedido inteiro vai para o fator" do
    count(raw: 15)
    assert_empty need.ready
    assert_equal 75, need.kg
    assert_equal 60, need.net_kg
  end

  test "produto pronto maior que o pedido abate só o pedido" do
    count(ready: 80)
    assert_equal({ @product => 50 }, need.ready)
    assert_equal 0, need.net_kg
    assert_equal 0, need.packages
  end

  test "produto pronto não abate pedido em outra unidade" do
    ActsAsTenant.with_tenant(company) { @product.update!(unit: "un") }
    count(ready: 10)
    assert_empty need.ready
  end
end
