require "test_helper"

# Passo 3 da esteira simplificada (o MVP): a compra é o volume total, os processados convertidos em matéria-prima pelo
# fator, sem abater estoque e sem caixas. Pedido de 50 kg com fator 1,50: 75 kg, mesmo com produto pronto e matéria-prima
# contados no Estoque.
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
    end
  end

  # A produção é a véspera da entrega (14/10): cai na compra de 13/10.
  def need = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "vegetal_esteira", "kg")

  test "pedido vezes o fator: 75 kg, sem caixas" do
    assert_equal 75, need.kg
    assert_equal 75, need.net_kg
    assert_nil need.packages
    assert_equal "75 kg", Formatting.need_text(need)
  end

  test "produto pronto e matéria-prima contados não abatem a compra" do
    ActsAsTenant.with_tenant(company) do
      ProductStockCount.create!(product: @product, date: Date.new(2026, 10, 12), quantity: 10)
      StockCount.create!(raw_material: @raw_material, date: Date.new(2026, 10, 12), kg: 15)
    end
    assert_empty need.ready
    assert_equal 0, need.stock_kg
    assert_equal 75, need.net_kg
  end

  test "o arredondamento do produto não muda o volume" do
    ActsAsTenant.with_tenant(company) { @product.update!(rounding: :fraction) }
    assert_equal "75 kg", Formatting.need_text(need)
  end
end
