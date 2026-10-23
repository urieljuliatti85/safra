require "test_helper"

class StockTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(user_for(:office))
    ActsAsTenant.current_tenant = company
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def raw_material(code) = RawMaterial.find_by!(code: code)

  test "a tela mostra a próxima compra e o que cada matéria-prima precisa" do
    get stock_path(date: "2026-10-12")
    assert_response :success
    assert_select "h1", "Estoque da câmara fria"
    assert_match "Próxima compra a partir desta contagem", response.body
    assert_match "Ter 13/10", response.body
    assert_select "th", text: /Precisa em 13\/10/
    assert_select "input[aria-label='Contagem de Cenoura']"
    assert_select "nav[aria-label='Principal'] a", text: "Estoque"
  end

  test "por padrão só aparece o que a compra precisa ou já tem contagem; mostrar todas inclui o resto" do
    get stock_path(date: "2026-10-12", q: "abacate")
    assert_select "input[aria-label='Contagem de Abacate']", false # abacate não entra na compra de 13/10
    assert_match "Nenhuma matéria-prima para mostrar", response.body
    get stock_path(date: "2026-10-12", q: "abacate", todas: "1")
    assert_select "input[aria-label='Contagem de Abacate']"
  end

  test "salvar cria contagens com vírgula e mostra o abate na compra" do
    cenoura = raw_material("cenoura")
    patch stock_path, params: { date: "2026-10-12", counts: { cenoura.id => "12,5" } }
    assert_redirected_to stock_path(date: "2026-10-12")
    follow_redirect!
    assert_match "1 contagem salva em 12/10", response.body
    assert_equal 12.5, StockCount.find_by!(raw_material: cenoura, date: "2026-10-12").kg.to_f
    assert_select "input[aria-label='Contagem de Cenoura'][value='12,5']"

    get purchases_path(date: "2026-10-13")
    assert_select "tr", text: /Cenoura/ do |rows|
      assert rows.any? { |row| row.text.include?("12,5 kg") }, "a compra deveria mostrar o abate de 12,5 kg"
    end
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

  test "sobra da contagem passa para a compra seguinte e as duas avisam, em ordem" do
    publish_purchase(Date.new(2026, 10, 13))
    publish_purchase(Date.new(2026, 10, 15))
    patch stock_path, params: { date: "2026-10-12", counts: { raw_material("cenoura").id => "1000" } }
    follow_redirect!
    assert_match "compra de 13/10, 15/10 mudou desde a versão enviada", response.body
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
    assert_select "input[name='counts[#{raw_material('cenoura').id}]']"
    patch stock_path, params: { date: "2026-10-12", counts: { raw_material("cenoura").id => "5" } }
    assert_redirected_to stock_path(date: "2026-10-12")
    assert_equal 5, StockCount.find_by!(raw_material: raw_material("cenoura"), date: "2026-10-12").kg
    follow_redirect!
    assert_no_match "mudou desde a versão enviada", response.body
  end

  test "sem dia de compra depois da data a tela avisa e continua usável" do
    get stock_path(date: "2026-12-01")
    assert_response :success
    assert_match "Não há dia de compra a partir de 01/12", response.body
  end
end
