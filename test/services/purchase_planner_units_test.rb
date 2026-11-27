require "test_helper"

# Fruta pedida por unidade na compra: no MVP (esteira simplificada) entra no volume total em unidades, sem caixas;
# sem as unidades por caixa cadastradas, a Conferência avisa.
class PurchasePlannerUnitsTest < ActiveSupport::TestCase
  DELIVERY = Date.new(2026, 10, 15)

  setup do
    ActsAsTenant.with_tenant(company) do
      @order = Order.joins(:customer).find_by!(customers: { code: "hbp" }, week_start: Date.new(2026, 10, 12))
      @laranja = Product.find_by!(code: "laranja_desc")
      OrderLine.where(product: @laranja).delete_all
    end
  end

  def order(product, quantity, unit: "un")
    ActsAsTenant.with_tenant(company) { @order.lines.create!(product: product, delivery_date: DELIVERY, quantity: quantity, unit: unit) }
  end

  def need(code, unit = "un")
    PurchasePlanner.new(company: company).call.purchases.values.flatten.find { |n| n.raw_material.code == code && n.unit == unit }
  end

  test "laranja pedida por unidade entra no volume total em unidades, sem caixas e sem alerta de fator" do
    order(@laranja, 250)
    laranja = need("laranja")
    assert_nil laranja.packages
    assert_not laranja.missing_factor
    assert_equal "250 un", Formatting.need_text(laranja)
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
