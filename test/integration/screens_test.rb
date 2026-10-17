require "test_helper"

class ScreensTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(user_for(:office)) }

  test "grade de pedidos mostra o cliente, as datas e os produtos" do
    get orders_path(customer: "hbp", week: "2026-10-12")
    assert_response :success
    assert_select "h1", /Hospital Bom Pastor/
    assert_select "th", /13\/10/
    assert_select "input[aria-label^='Cenoura em cubinhos']"
  end

  test "observação da linha aparece por extenso na grade e na programação" do
    ActsAsTenant.with_tenant(company) do
      OrderLine.joins(order: :customer).where(customers: { code: "hbp" }).where(delivery_date: Date.new(2026, 10, 14)).first
               .update!(note: "entregar até 7h")
    end
    get orders_path(customer: "hbp", week: "2026-10-12")
    assert_select ".line-note", /entregar até 7h/
    assert_select ".tag-change", text: "obs.", count: 0
    get schedule_path(date: "2026-10-14")
    assert_select ".line-note", /entregar até 7h/
  end

  test "salvar a grade altera o pedido e avisa quando o plano enviado mudou" do
    ActsAsTenant.with_tenant(company) do
      PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call)
    end
    product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "cenoura_ralada") }
    customer = ActsAsTenant.with_tenant(company) { Customer.find_by!(code: "hnorte") }
    patch orders_path(customer: customer.code, week: "2026-10-12"), params: { quantities: { "#{product.id}|kg" => { "2026-10-13" => "9" } } }
    assert_redirected_to orders_path(customer: "hnorte", week: "2026-10-12")
    follow_redirect!
    assert_match "Pedido salvo", response.body
    assert_match "mudou desde a versão enviada", response.body
  end

  test "salvar com texto inválido não grava e mostra o erro" do
    product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "cenoura_ralada") }
    patch orders_path(customer: "hnorte", week: "2026-10-12"), params: { quantities: { "#{product.id}|kg" => { "2026-10-13" => "5 + 2" } } }
    assert_response :unprocessable_entity
    assert_match "não é um número", response.body
  end

  test "produção do dia agrupa por setor e mostra aprontes" do
    get production_path(date: "2026-10-13")
    assert_response :success
    assert_select "h2", "Ralados, picados e rodelas"
    assert_select "h2", /Aprontes/
    assert_select "td", "Cenoura ralada"
  end

  test "produção filtrada por setor mostra só a lista daquela bancada, na tela e no PDF" do
    get production_path(date: "2026-10-13", sector: "ralpic")
    assert_select "nav[aria-label='Setores'] a[aria-current='true']", "Ralados, picados e rodelas"
    assert_select "h2", "Ralados, picados e rodelas"
    assert_select "h2", text: "Cortes manuais", count: 0
    assert_select "h2", text: "Aprontes", count: 0
    assert_select "a[aria-label='Próximo dia'][href*='sector=ralpic']"

    get production_path(date: "2026-10-13", sector: "aprontes")
    assert_select "h2", "Aprontes"
    assert_select "h2", text: "Ralados, picados e rodelas", count: 0

    get production_path(date: "2026-10-13", sector: "lixo")
    assert_select "nav[aria-label='Setores'] a[aria-current='true']", "Todos"
    assert_select "h2", "Cortes manuais"

    get production_path(date: "2026-10-13", sector: "ralpic", format: :pdf)
    assert_equal "application/pdf", response.media_type
    assert_match "producao-2026-10-13-ralpic.pdf", response.headers["Content-Disposition"]
  end

  test "enviar aos setores cria a versão e a tela passa a mostrar igual" do
    assert_difference -> { ActsAsTenant.with_tenant(company) { ProductionPlan.count } }, 1 do
      post publish_production_path(date: "2026-10-13")
    end
    follow_redirect!
    assert_match "versão 1", response.body
    assert_match "Igual ao que foi enviado", response.body
  end

  test "compras têm texto para WhatsApp por fornecedor" do
    get purchases_path(date: "2026-10-13")
    assert_response :success
    assert_select "textarea[aria-label='Texto do pedido para Fornecedor B']", /\*Fornecedor B · compra 13\/10\*/
  end

  test "programação por dia de entrega" do
    get schedule_path(date: "2026-10-14")
    assert_response :success
    assert_select "h2", "Hospital Bom Pastor"
  end

  test "conferência e comparação com planilhas" do
    get conference_path
    assert_response :success
    get conference_sheets_path
    assert_response :success
    assert_match "iguais", response.body
  end

  test "PDFs de programação, produção e compras" do
    [ schedule_path(date: "2026-10-14", format: :pdf), production_path(date: "2026-10-13", format: :pdf),
      purchases_path(date: "2026-10-13", format: :pdf) ].each do |path|
      get path
      assert_response :success
      assert_equal "application/pdf", response.media_type
      assert response.body.start_with?("%PDF"), "#{path} não gerou PDF"
    end
  end

  test "dia sem produção ou data inválida não quebra" do
    get production_path(date: "2026-10-11")
    assert_response :success
    get production_path(date: "lixo")
    assert_response :success
  end
end
