require "test_helper"

# Recebimento e conferência (R5.1, R5.2, D47): o recebido na unidade da relação, a diferença para o enviado e a
# matéria-prima disponível no Estoque.
class PurchaseReceiptsTest < ActionDispatch::IntegrationTest
  DATE = Date.new(2026, 10, 13)

  setup do
    sign_in_as(user_for(:office))
    ActsAsTenant.current_tenant = company
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def publish
    PlanPublisher.purchase(company: company, date: DATE, needs: PurchasePlanner.new(company: company).call.purchases.fetch(DATE))
  end

  def cenoura_item(plan) = plan.items.find { |i| i.raw_material.code == "cenoura" && i.unit == "kg" }

  test "sem compra enviada, o recebimento avisa e não tem formulário" do
    get purchase_receipt_path(date: DATE)
    assert_response :success
    assert_match "ainda não foi enviada aos fornecedores", response.body
    assert_select "form[action='#{purchase_receipt_path}']", 0
  end

  test "registra o recebido em caixas e avulso, mostra a diferença e a divergência" do
    item = cenoura_item(publish)
    get purchases_path(date: DATE)
    assert_select "a[href=?]", purchase_receipt_path(date: DATE), text: /Recebimento/

    get purchase_receipt_path(date: DATE)
    assert_select "td", Formatting.need_text(item)
    patch purchase_receipt_path, params: { date: DATE.iso8601, receipts: { item.id => { packages: (item.packages - 1).to_s, loose: "", note: "1 caixa não veio" } } }
    assert_redirected_to purchase_receipt_path(date: DATE)
    follow_redirect!
    assert_match "Recebimento de 13/10 salvo", response.body

    receipt = PurchaseReceipt.find_by!(date: DATE, raw_material: item.raw_material, unit: "kg")
    assert_equal item.packages - 1, receipt.packages
    assert_equal "1 caixa não veio", receipt.note
    expected = item.quantity - receipt.quantity
    assert_select "td", "faltou #{Formatting.qty(expected)} kg"
  end

  test "linha vazia apaga o registro" do
    item = cenoura_item(publish)
    PurchaseReceipt.create!(date: DATE, raw_material: item.raw_material, unit: "kg", packages: 1)
    patch purchase_receipt_path, params: { date: DATE.iso8601, receipts: { item.id => { packages: "", loose: "", note: "" } } }
    assert_nil PurchaseReceipt.find_by(date: DATE, raw_material: item.raw_material)
  end

  test "número inválido não salva nada" do
    item = cenoura_item(publish)
    patch purchase_receipt_path, params: { date: DATE.iso8601, receipts: { item.id => { packages: "-2" } } }
    assert_response :unprocessable_entity
    assert_match "Nada foi salvo", response.body
    assert_nil PurchaseReceipt.find_by(date: DATE, raw_material: item.raw_material)
  end

  test "o recebido depois da última contagem entra na matéria-prima disponível" do
    item = cenoura_item(publish)
    cenoura = item.raw_material
    StockCount.create!(raw_material: cenoura, date: Date.new(2026, 10, 12), kg: 10)
    PurchaseReceipt.create!(date: DATE, raw_material: cenoura, unit: "kg", packages: 2, loose: 5)
    received = 2 * cenoura.kg_per_package + 5
    get stock_path(date: "2026-10-14")
    assert_select "tr", text: /Cenoura\b.*#{Formatting.qty(received)} kg.*#{Formatting.qty(10 + received)} kg/m
  end

  test "quem é da produção não registra recebimento" do
    sign_in_as(user_for(:production))
    get purchase_receipt_path(date: DATE)
    assert_redirected_to production_path
  end
end
