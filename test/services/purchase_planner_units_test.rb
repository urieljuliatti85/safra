require "test_helper"

# Fruta pedida por unidade na compra (R3.10, D40): laranja, 100 unidades por caixa; melancia, comprada por unidade;
# sem as unidades por caixa, a compra fica na quantidade pedida e a Conferência avisa.
class PurchasePlannerUnitsTest < ActiveSupport::TestCase
  DELIVERY = Date.new(2026, 10, 15)

  setup do
    ActsAsTenant.with_tenant(company) do
      @order = Order.joins(:customer).find_by!(customers: { code: "hbp" }, week_start: Date.new(2026, 10, 12))
      @laranja = Product.find_by!(code: "laranja_desc")
      @purchase_date = PurchaseDay.where(date: ..@laranja.production_date_for(DELIVERY)).maximum(:date)
      OrderLine.where(product: @laranja).delete_all
    end
  end

  def order(product, quantity, unit: "un")
    ActsAsTenant.with_tenant(company) { @order.lines.create!(product: product, delivery_date: DELIVERY, quantity: quantity, unit: unit) }
  end

  def need(code, unit = "un")
    PurchasePlanner.new(company: company).call.purchases.values.flatten.find { |n| n.raw_material.code == code && n.unit == unit }
  end

  test "laranja pedida por unidade vira caixas de 100, arredondadas para cima, sem alerta de fator" do
    order(@laranja, 250)
    laranja = need("laranja")
    assert_equal 3, laranja.packages
    assert_equal 2.5, laranja.net_packages
    assert_not laranja.missing_factor
    assert_equal "3 cx", Formatting.need_text(laranja)
  end

  test "laranja em fração: caixas inteiras e o resto em unidades" do
    ActsAsTenant.with_tenant(company) { @laranja.update!(rounding: :fraction) }
    order(@laranja, 250)
    laranja = need("laranja")
    assert_equal [ 2, 50 ], [ laranja.packages, laranja.loose_units ]
    assert_equal "2 cx e 50 un", Formatting.need_text(laranja)
  end

  test "melancia comprada por unidade: compra as unidades pedidas" do
    melancia = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "in_melancia") }
    order(melancia, 8)
    assert_equal "8 un", Formatting.need_text(need("melancia"))
  end

  test "sem unidades por caixa a compra fica na quantidade pedida e a Conferência avisa" do
    ActsAsTenant.with_tenant(company) { RawMaterial.find_by!(code: "laranja").update!(units_per_package: nil) }
    order(@laranja, 250)
    laranja = need("laranja")
    assert_nil laranja.packages
    assert laranja.missing_factor
    alerts = ConferenceChecker.new(company: company).call
    assert(alerts.any? { |a| a.kind == "Sem unidades por caixa" && a.message.start_with?("Laranja pera:") })
  end

  test "com as unidades por caixa a Conferência não acusa falta de fator na laranja descascada" do
    order(@laranja, 250)
    alerts = ConferenceChecker.new(company: company).call
    assert_not(alerts.any? { |a| a.kind == "Sem fator" && a.message.start_with?("Laranja pera:") })
    assert_not(alerts.any? { |a| a.kind == "Sem unidades por caixa" && a.message.start_with?("Laranja pera:") })
  end
end
