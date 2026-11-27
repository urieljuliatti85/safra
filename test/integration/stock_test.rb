require "test_helper"

class StockTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(user_for(:office))
    ActsAsTenant.current_tenant = company
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def raw_material(code) = RawMaterial.find_by!(code: code)

  # MVP (esteira simplificada, passo 5): o Estoque é o produto pronto que sobrou; a matéria-prima não é contada na tela.
  test "a tela mostra só o produto pronto" do
    get stock_path(date: "2026-10-12")
    assert_response :success
    assert_select "h1", "Estoque da câmara fria"
    assert_select ".page-sub", /produto pronto que sobrou/
    assert_select "h2", "Produto pronto"
    assert_select "input[aria-label='Contagem de Cenoura']", false
    assert_select "nav[aria-label='Principal'] a", text: "Estoque"
  end

  test "salvar cria contagens com vírgula" do
    cenoura = raw_material("cenoura")
    patch stock_path, params: { date: "2026-10-12", counts: { cenoura.id => "12,5" } }
    assert_redirected_to stock_path(date: "2026-10-12")
    follow_redirect!
    assert_match "1 contagem salva em 12/10", response.body
    assert_equal 12.5, StockCount.find_by!(raw_material: cenoura, date: "2026-10-12").kg.to_f
  end

  test "campo vazio apaga a contagem, zero guarda a câmara vazia e linha igual não conta" do
    cenoura = raw_material("cenoura")
    StockCount.create!(raw_material: cenoura, date: "2026-10-12", kg: 8)
    patch stock_path, params: { date: "2026-10-12", counts: { cenoura.id => "8" } }
    follow_redirect!
    assert_match "Nada mudou", response.body

    patch stock_path, params: { date: "2026-10-12", counts: { cenoura.id => "0" } }
    assert_equal 0, StockCount.find_by!(raw_material: cenoura, date: "2026-10-12").kg

    patch stock_path, params: { date: "2026-10-12", counts: { cenoura.id => "" } }
    assert_nil StockCount.find_by(raw_material: cenoura, date: "2026-10-12")
  end

  test "valor inválido não salva nada, nem as linhas certas" do
    cenoura = raw_material("cenoura")
    beterraba = raw_material("beterraba")
    patch stock_path, params: { date: "2026-10-12", counts: { cenoura.id => "10", beterraba.id => "muito" } }
    assert_response :unprocessable_entity
    assert_match "Beterraba: Kg não é um número", response.body
    assert_nil StockCount.find_by(raw_material: cenoura, date: "2026-10-12")

    patch stock_path, params: { date: "2026-10-12", counts: { cenoura.id => "-3" } }
    assert_response :unprocessable_entity
    assert_match "Cenoura: Kg deve ser maior ou igual a 0", response.body
  end

  test "contagem de outra empresa não entra" do
    other = Company.create!(name: "Outra")
    rm = ActsAsTenant.with_tenant(other) { RawMaterial.create!(name: "Alheia", code: "alheia", purchase_package: "kg") }
    patch stock_path, params: { date: "2026-10-12", counts: { rm.id => "5" } }
    assert_equal 0, ActsAsTenant.with_tenant(other) { StockCount.count }
  end

  test "compra já enviada avisa quando uma contagem nova a muda" do
    needs = PurchasePlanner.new(company: company).call.purchases.fetch(Date.new(2026, 10, 13))
    PlanPublisher.purchase(company: company, date: Date.new(2026, 10, 13), needs: needs)
    patch stock_path, params: { date: "2026-10-12", counts: { raw_material("cenoura").id => "50" } }
    follow_redirect!
    assert_match "compra de 13/10 mudou desde a versão enviada", response.body
  end

  def publish_purchase(date)
    needs = PurchasePlanner.new(company: company).call.purchases.fetch(date)
    PlanPublisher.purchase(company: company, date: date, needs: needs)
  end

  # Cenoura precisa de 268,65 kg em 13/10: 50 kg contados acabam nessa compra e não sobra nada para 15/10.
  test "com duas compras enviadas, avisa só a que a contagem muda" do
    publish_purchase(Date.new(2026, 10, 13))
    publish_purchase(Date.new(2026, 10, 15))
    patch stock_path, params: { date: "2026-10-12", counts: { raw_material("cenoura").id => "50" } }
    follow_redirect!
    assert_match "compra de 13/10 mudou desde a versão enviada", response.body
    assert_no_match "15/10 mudou", response.body
  end

  test "contagem maior que a compra muda só a compra seguinte a ela: a sobra não passa adiante" do
    publish_purchase(Date.new(2026, 10, 13))
    publish_purchase(Date.new(2026, 10, 15))
    patch stock_path, params: { date: "2026-10-12", counts: { raw_material("cenoura").id => "1000" } }
    follow_redirect!
    assert_match "compra de 13/10 mudou desde a versão enviada", response.body
    assert_no_match "15/10 mudou", response.body
  end

  test "contagem que não muda a compra enviada não avisa" do
    publish_purchase(Date.new(2026, 10, 13))
    patch stock_path, params: { date: "2026-10-12", counts: { raw_material("abacate").id => "5" } }
    follow_redirect!
    assert_match "1 contagem salva", response.body
    assert_no_match "mudou desde a versão enviada", response.body
  end

  test "compra enviada de outra empresa não entra no aviso" do
    other = Company.create!(name: "Outra")
    ActsAsTenant.with_tenant(other) do
      rm = RawMaterial.create!(name: "Alheia", code: "alheia", purchase_package: "kg")
      plan = PurchasePlan.create!(date: Date.new(2026, 10, 20), version: 1, sent_at: Time.current)
      plan.items.create!(raw_material: rm, kg: 10, unit: "kg")
    end
    assert_equal [ Date.new(2026, 10, 20) ], StalePlans.purchase_dates(other) # para a outra empresa a compra mudou

    patch stock_path, params: { date: "2026-10-12", counts: { raw_material("cenoura").id => "50" } }
    follow_redirect!
    assert_no_match "mudou desde a versão enviada", response.body
  end

  test "a tela de compras leva à contagem do dia" do
    get purchases_path(date: "2026-10-13")
    assert_select "a[href='#{stock_path(date: '2026-10-13')}']", text: /Contar estoque/
  end

  test "produção conta o estoque, mas não vê a compra" do
    sign_in_as(user_for(:production))
    get stock_path(date: "2026-10-12")
    assert_response :success
    assert_select "h1", /Estoque/
    assert_select "a[href^='#{purchases_path}']", count: 0
    assert_select "th", text: /Comprar|Abate do estoque|Precisa em/, count: 0
    patch stock_path, params: { date: "2026-10-12", counts: { raw_material("cenoura").id => "5" } }
    assert_redirected_to stock_path(date: "2026-10-12")
    assert_equal 5, StockCount.find_by!(raw_material: raw_material("cenoura"), date: "2026-10-12").kg
    follow_redirect!
    assert_no_match "mudou desde a versão enviada", response.body
  end

  test "produto pronto da próxima compra aparece para contar, na unidade do produto" do
    get stock_path(date: "2026-10-12")
    assert_select "h2", "Produto pronto"
    assert_select "input[aria-label='Contagem de Cenoura em cubinhos pronto, em kg']"
  end

  test "salvar o produto pronto abate o pedido antes do fator e aparece na compra" do
    product = Product.find_by!(code: "cenoura_cubinhos")
    before = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    patch stock_path, params: { date: "2026-10-12", ready_counts: { product.id => "1,5" } }
    follow_redirect!
    assert_match "1 contagem salva em 12/10", response.body
    assert_equal 1.5, ProductStockCount.find_by!(product: product, date: "2026-10-12").quantity.to_f

    after = PurchasePlanner.new(company: company).call.need_for(Date.new(2026, 10, 13), "cenoura", "kg")
    assert_equal({ product => 1.5 }, after.ready)
    assert_in_delta before.kg - 1.5 * product.raw_material.multiply_factor, after.kg, 0.001

    get purchases_path(date: "2026-10-13")
    assert_match "Produto pronto: Cenoura em cubinhos 1,5 kg abatido do pedido, antes do fator", response.body
  end

  test "erro no produto pronto não salva nem a matéria-prima" do
    product = Product.find_by!(code: "cenoura_cubinhos")
    cenoura = raw_material("cenoura")
    patch stock_path, params: { date: "2026-10-12", counts: { cenoura.id => "5" }, ready_counts: { product.id => "-1" } }
    assert_response :unprocessable_entity
    assert_match "Cenoura em cubinhos pronto", response.body
    assert_nil StockCount.find_by(raw_material: cenoura, date: "2026-10-12")
  end
end
