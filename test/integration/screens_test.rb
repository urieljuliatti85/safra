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

  test "no celular a grade abre no dia de hoje quando ele está na semana" do
    travel_to(Time.zone.local(2026, 10, 15, 9)) { get orders_path(customer: "ahotel", week: "2026-10-12") }
    assert_select "form[data-controller='order-day'][data-order-day-index-value='3']" # Qui 15/10
  end

  test "no celular, fora da semana de hoje, a grade abre no primeiro dia com pedido" do
    travel_to(Time.zone.local(2026, 11, 1, 9)) { get orders_path(customer: "ahotel", week: "2026-10-12") }
    assert_select "form[data-controller='order-day'][data-order-day-index-value='1']" # Ter 13/10, não a segunda vazia
  end

  test "número da faixa da semana leva à produção do setor e à lista dele na página" do
    get production_path(date: "2026-10-13")
    link = css_select("a.bar[aria-label='Cortes manuais, Ter 13/10: 8 itens']").first
    assert link, "número de Cortes manuais em 13/10 na faixa"
    path, anchor = link["href"].split("#")
    assert_equal "setor-manual", anchor

    get path
    assert_response :success
    assert_select "section##{anchor} h2", "Cortes manuais"
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
    patch orders_path(customer: customer.code, week: "2026-10-12"), params: { quantities: { "#{product.id}|kg" => { "2026-10-13" => "9" } }, late_confirmed: "1" }
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

  test "produção vazia explica as linhas in natura e só é enviada com confirmação" do
    ActsAsTenant.with_tenant(company) do
      order = Order.create!(customer: Customer.first, week_start: Date.new(2026, 11, 2))
      order.lines.create!(product: Product.find_by!(product_group: "raw"), delivery_date: Date.new(2026, 11, 4), quantity: 10, unit: "kg")
    end

    customer = ActsAsTenant.with_tenant(company) { Customer.first.short_name }
    get production_path(date: "2026-11-03")
    assert_select "p[role='note']", /Nenhum item para produzir em 03\/11\. A linha in natura de #{customer} \(entrega de 04\/11\) vai direto para a compra/
    assert_select "p[role='note'] a", "Abrir a compra"
    assert_select "form[data-turbo-confirm*='Nenhum item para produzir em 03/11'] input[name='empty'][value='1']"

    # No dia da entrega a produção também explica, mesmo sem nada para enviar.
    get production_path(date: "2026-11-04")
    assert_select "p[role='note']", /A linha in natura de #{customer} \(entrega de 04\/11\)/

    assert_no_difference -> { ActsAsTenant.with_tenant(company) { ProductionPlan.count } } do
      post publish_production_path(date: "2026-11-03")
    end
    follow_redirect!
    assert_select ".flash-alert", /vai direto para a compra\. Confirme/

    assert_difference -> { ActsAsTenant.with_tenant(company) { ProductionPlan.count } }, 1 do
      post publish_production_path(date: "2026-11-03", empty: 1)
    end
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

  test "conferência mostra o botão de cada alerta e ele abre o destino" do
    get conference_path(week: "2026-10-12")
    assert_response :success
    item = css_select(".alert-item").find { |li| li.text.include?("Cebola: sem fator") }
    assert item, "alerta de fator da Cebola"
    link = item.css("a.alert-action").first
    assert_equal "Completar o fator", link.text
    get link["href"]
    assert_response :success
    assert_select "th a.underline", text: /Cebola/
    assert_select "th a.underline", text: /Cenoura/, count: 0
  end

  test "conferência mostra a semana pedida, a atual por padrão e todas com ?week=todas" do
    get conference_path(week: "2026-10-14")
    assert_select "strong", "Semana de 12/10 a 18/10"
    assert_select ".alert-item", minimum: 1

    get conference_path(week: "2026-10-26")
    assert_select "strong", "Semana de 26/10 a 01/11"
    assert_select ".alert-item", count: 0
    assert_match "Nada a conferir na semana de 26/10 a 01/11", response.body
    assert_match "Há alertas de atenção em outras semanas", response.body
    assert_select "a[aria-label='Semana anterior'][href='/conference?week=2026-10-19']"

    travel_to(Time.zone.local(2026, 10, 14, 9)) do
      get conference_path
      assert_select "strong", "Semana de 12/10 a 18/10"
      assert_select "a.chip[aria-current='true']", "Esta semana"
    end

    get conference_path(week: "todas")
    assert_select "strong", "Todas as semanas"
    assert_select "a.chip[aria-current='true']", /Todas as semanas \(\d+\)/
    assert_select ".alert-item", minimum: 1
  end

  test "cadastro de matérias-primas filtra as que não têm fornecedor" do
    ActsAsTenant.with_tenant(company) { RawMaterial.first.update_columns(supplier_id: nil) }
    get raw_materials_path(filter: "no_supplier")
    assert_response :success
    assert_select "a.chip[aria-current='true']", /Sem fornecedor \(\d+\)/
    get raw_materials_path(filter: "lixo")
    assert_select "a.chip[aria-current='true']", /Todas/
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
