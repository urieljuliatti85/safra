require "test_helper"

class RulesTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(user_for(:office))
    ActsAsTenant.current_tenant = company
    @cubinhos = Cut.find_by!(code: "cubinhos")
    @cubos = Cut.find_by!(code: "cubos")
  end

  teardown { ActsAsTenant.current_tenant = nil }

  test "a tela lista os cortes, o in natura, as exceções e os dias de compra" do
    get rules_path
    assert_response :success
    assert_select "h1", "Regras de produção"
    assert_select "label[for=cut_#{@cubinhos.id}]", /Cubinhos/
    assert_select "select#cut_#{@cubinhos.id} option[selected]", "1 dia antes"
    assert_select "select#raw_lead_days option[selected]", "1 dia antes"
    assert_match "Placar contra as planilhas", response.body
    assert_match "13 de 43", response.body
    assert_select "#compras li", 3
  end

  test "ver efeito mostra o placar antes e depois e não grava nada" do
    patch rules_path, params: { commit_action: "simulate", cut_leads: { @cubinhos.id => "0" } }
    assert_response :success
    assert_match "Efeito sem salvar", response.body
    assert_match "Nada foi gravado", response.body
    assert_match "13 → 19", response.body
    assert_match "passam a bater", response.body
    assert_equal 1, @cubinhos.reload.lead_days
    assert_select "select#cut_#{@cubinhos.id} option[selected]", "No dia da entrega" # o formulário guarda o que foi digitado
  end

  test "salvar grava a antecedência do corte e avisa quando um plano enviado mudou" do
    PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call)
    patch rules_path, params: { commit_action: "save", cut_leads: { @cubinhos.id => "0", @cubos.id => "1" }, raw_lead_days: "2" }
    assert_redirected_to rules_path
    follow_redirect!
    assert_match "Regras salvas", response.body
    assert_match "mudou desde a versão enviada", response.body
    assert_equal 0, @cubinhos.reload.lead_days
    assert_equal 2, company.reload.raw_lead_days
  end

  test "valor inválido não salva nada, nem o que estava certo" do
    patch rules_path, params: { commit_action: "save", cut_leads: { @cubinhos.id => "0", @cubos.id => "9" } }
    assert_response :unprocessable_entity
    assert_match "Nada foi salvo", response.body
    assert_equal 1, @cubinhos.reload.lead_days
    assert_equal 1, @cubos.reload.lead_days
  end

  test "criar, mudar e apagar exceção por produto" do
    product = Product.find_by!(code: "batata_cubos")
    patch rules_path, params: { commit_action: "save", new_exception: { product_id: product.id, lead_days: "0" } }
    assert_equal 0, product.reload.lead_days
    assert_equal Date.new(2026, 10, 14), product.production_date_for(Date.new(2026, 10, 14)) # no dia da entrega

    patch rules_path, params: { commit_action: "save", exceptions: { product.id => "2" } }
    assert_equal 2, product.reload.production_rule.lead_days

    patch rules_path, params: { commit_action: "save", exceptions: { product.id => "" } }
    assert_nil product.reload.production_rule
    assert_equal @cubos.lead_days, product.lead_days
  end

  test "a antecedência do in natura vale para a compra" do
    produto = Product.find_by!(code: "in_agriao")
    assert_equal Date.new(2026, 10, 13), produto.production_date_for(Date.new(2026, 10, 14))
    patch rules_path, params: { commit_action: "save", raw_lead_days: "2" }
    company.reload # numa requisição real a empresa é carregada de novo
    assert_equal Date.new(2026, 10, 12), Product.find(produto.id).production_date_for(Date.new(2026, 10, 14))
  end

  test "corte de outra empresa não é alterado" do
    other = Company.create!(name: "Outra")
    cut = ActsAsTenant.with_tenant(other) { Cut.create!(code: "x", name: "X", sector: "manual", sector_name: "Cortes manuais", lead_days: 1) }
    patch rules_path, params: { commit_action: "save", cut_leads: { cut.id => "3" } }
    assert_response :unprocessable_entity
    assert_equal 1, ActsAsTenant.with_tenant(other) { cut.reload.lead_days }
  end

  test "adicionar e remover dia de compra" do
    post purchase_days_path, params: { date: "2026-10-22" }
    assert_redirected_to rules_path(anchor: "compras")
    day = PurchaseDay.find_by!(date: "2026-10-22")
    follow_redirect!
    assert_match "adicionado", response.body

    post purchase_days_path, params: { date: "2026-10-22" }
    follow_redirect!
    assert_match "já existia", response.body

    delete purchase_day_path(day)
    assert_not PurchaseDay.exists?(day.id)
  end

  test "data inválida de compra não cria" do
    assert_no_difference -> { PurchaseDay.count } do
      post purchase_days_path, params: { date: "lixo" }
    end
    assert_redirected_to rules_path(anchor: "compras")
  end

  test "produção não acessa as regras" do
    sign_in_as(user_for(:production))
    get rules_path
    assert_redirected_to production_path
    patch rules_path, params: { commit_action: "save", cut_leads: { @cubinhos.id => "0" } }
    assert_redirected_to production_path
    assert_equal 1, @cubinhos.reload.lead_days
    post purchase_days_path, params: { date: "2026-10-22" }
    assert_redirected_to production_path
  end
end
