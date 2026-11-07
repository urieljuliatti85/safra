require "test_helper"

class OrderImportsTest < ActionDispatch::IntegrationTest
  setup do
    # Antes das 48 h da entrega (R1.26, D8): estes testes não são sobre o prazo de alteração.
    travel_to Time.zone.local(2026, 10, 5, 9)
  end

  setup { sign_in_as(user_for(:office)) }

  def upload(name, customer)
    post order_imports_path, params: { customer: customer, file: fixture_file_upload(name, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") }
  end

  test "formulário de importação" do
    get new_order_import_path(customer: "hbp")
    assert_response :success
    assert_select "h1", /Importar planilha/
    assert_select "option[selected]", /Hospital Bom Pastor/
    assert_select "input[type=file][accept*='.xlsx']"
  end

  test "link na grade de pedidos leva à importação" do
    get orders_path(customer: "hbp", week: "2026-10-12")
    assert_select "a[href*='order_imports/new']", /Importar planilha/
  end

  test "enviar a planilha mostra a conferência com o que muda" do
    upload("pedido_com_unidade.xlsx", "hnorte")
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_select "h1", /Conferir planilha/
    assert_match "pedido_com_unidade.xlsx", response.body
    assert_select "select[aria-label='Produto para ABÓBORA CUBOS'] option[selected]", /Abóbora em cubos/
    assert_match "somado como 7", response.body
    assert_select "button", /Importar no pedido/
  end

  test "produto desconhecido aparece para escolher e aplicar sem escolher mostra o erro" do
    upload("pedido_sem_unidade.xlsx", "hbp")
    follow_redirect!
    assert_match "1 produto para escolher", response.body
    import = ActsAsTenant.with_tenant(company) { OrderImport.order(:id).last }
    post apply_order_import_path(import)
    assert_response :unprocessable_entity
    assert_match "escolha o produto", response.body
  end

  test "aplicar grava o pedido e volta para a grade com o aviso" do
    upload("pedido_com_unidade.xlsx", "hnorte")
    import = ActsAsTenant.with_tenant(company) { OrderImport.order(:id).last }
    post apply_order_import_path(import)
    assert_redirected_to orders_path(customer: "hnorte", week: "2026-10-12")
    follow_redirect!
    assert_match "Planilha importada no pedido", response.body
    assert_select "a.pill-undo[href='#{order_import_path(import, anchor: 'desfazer')}']", /Desfazer pedido_com_unidade.xlsx/
    assert_equal "applied", ActsAsTenant.with_tenant(company) { import.reload.status }
  end


  test "desfazer pela tela devolve o pedido e reabre a importação" do
    upload("pedido_com_unidade.xlsx", "hnorte")
    import = ActsAsTenant.with_tenant(company) { OrderImport.order(:id).last }
    post apply_order_import_path(import)
    get order_import_path(import)
    assert_select "section[aria-label='Desfazer importação'] button", /Desfazer importação/
    post undo_order_import_path(import)
    assert_redirected_to order_import_path(import)
    follow_redirect!
    assert_match "Importação desfeita", response.body
    assert_select "button", /Importar no pedido/
    assert_equal "pending", ActsAsTenant.with_tenant(company) { import.reload.status }
  end

  test "planilha aplicada não é reaberta pelo status, só desfazendo" do
    upload("pedido_com_unidade.xlsx", "hnorte")
    import = ActsAsTenant.with_tenant(company) { OrderImport.order(:id).last }
    post apply_order_import_path(import)
    patch settings_order_import_path(import), params: { status: "pending" }
    assert_equal "applied", ActsAsTenant.with_tenant(company) { import.reload.status }
  end

  test "salvar a grade cria versão, a versão mostra o que mudou e pode ser restaurada" do
    product, order = ActsAsTenant.with_tenant(company) do
      [ Product.find_by!(code: "cenoura_cubinhos"), Order.find_by!(customer: Customer.find_by!(code: "hbp"), week_start: Date.new(2026, 10, 12)) ]
    end
    patch orders_path(customer: "hbp", week: "2026-10-12"), params: { quantities: { "#{product.id}|kg" => { "2026-10-18" => "3" } } }
    follow_redirect!
    assert_match "Pedido salvo: versão 2, 1 alteração.", response.body
    assert_select "a[href='#versoes']", /Versões\s+v2/
    assert_select "section#versoes h2", "Versões desta semana"
    assert_select "section#versoes li", 2
    assert_select "section#versoes li", /v2\s+Grade/
    assert_select "section#versoes li", /Antes do primeiro salvamento/

    initial, latest = ActsAsTenant.with_tenant(company) { order.versions.order(:version).to_a }
    get order_version_path(latest)
    assert_response :success
    assert_select "h1", "Versão 2 do pedido"
    assert_select "td", "Cenoura em cubinhos kg"
    assert_select "button", { text: /Restaurar esta versão/, count: 0 }

    get order_version_path(initial)
    post restore_order_version_path(initial)
    assert_redirected_to orders_path(customer: "hbp", week: Date.new(2026, 10, 12))
    follow_redirect!
    assert_match "voltou à versão 1", response.body
    assert_select "section#versoes li", /v3\s+Versão restaurada \(v1\)/
  end

  test "salvar sem mudar nada avisa que não houve versão nova" do
    product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "cenoura_cubinhos") }
    patch orders_path(customer: "hbp", week: "2026-10-12"), params: { quantities: { "#{product.id}|kg" => { "2026-10-30" => "" } } }
    follow_redirect!
    assert_match "Nada mudou no pedido", response.body
    assert_select "section#versoes li", 0
  end

  test "produção não vê nem restaura versões do pedido" do
    version = ActsAsTenant.with_tenant(company) do
      order = Order.find_by!(customer: Customer.find_by!(code: "hbp"), week_start: Date.new(2026, 10, 12))
      order.versions.create!(version: 1, source: "grid", lines: [])
    end
    sign_in_as(user_for(:production))
    get order_version_path(version)
    assert_response :redirect
    post restore_order_version_path(version)
    assert_response :redirect
    assert_equal 1, ActsAsTenant.with_tenant(company) { version.order.versions.count }
  end

  test "sem arquivo não envia" do
    post order_imports_path, params: { customer: "hbp" }
    assert_response :unprocessable_entity
    assert_match "Escolha o cliente e o arquivo", response.body
  end

  test "ODT com imagens leva à tela de digitação com a imagem ao lado da grade" do
    post order_imports_path, params: { customer: "hbp", file: fixture_file_upload("pedidos_documento.odt", "application/vnd.oasis.opendocument.text") }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_select "h1", /Pedido em imagem/
    assert_select "img[alt^='Pedido enviado pelo cliente']"
    assert_select "nav[aria-label='Imagens do documento'] a", 2
    assert_select "input[aria-label*='Abóbora em cubinhos']", false # grade vazia: só as linhas com quantidade ou adicionadas
    assert_select "select#customer option[selected]", /Aurora · Mollinari/
  end

  test "digitar olhando a imagem grava no pedido do cliente e volta para a mesma imagem" do
    post order_imports_path, params: { customer: "hbp", file: fixture_file_upload("pedidos_documento.odt", "application/vnd.oasis.opendocument.text") }
    import = ActsAsTenant.with_tenant(company) { OrderImport.images.order(:id).first }
    product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "brocolis") }
    patch grid_order_import_path(import), params: { quantities: { "#{product.id}|kg" => { "2026-10-12" => "30" } } }
    assert_redirected_to order_import_path(import)
    quantity = ActsAsTenant.with_tenant(company) do
      Order.find_by!(customer: import.customer, week_start: import.week_start).lines.where(product: product, delivery_date: "2026-10-12").sum(:quantity)
    end
    assert_equal 30, quantity
  end

  test "texto inválido na digitação não grava e mostra o erro na mesma tela" do
    post order_imports_path, params: { customer: "hbp", file: fixture_file_upload("imagem_pedido.png", "image/png") }
    import = ActsAsTenant.with_tenant(company) { OrderImport.images.order(:id).last }
    product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "brocolis") }
    patch grid_order_import_path(import), params: { quantities: { "#{product.id}|kg" => { "2026-10-12" => "5 + 2" } } }
    assert_response :unprocessable_entity
    assert_match "não é um número", response.body
    assert_select "img[alt^='Pedido enviado pelo cliente']"
  end

  test "trocar o cliente e a semana e marcar como digitada" do
    post order_imports_path, params: { customer: "hbp", file: fixture_file_upload("imagem_pedido.png", "image/png") }
    import = ActsAsTenant.with_tenant(company) { OrderImport.images.order(:id).last }
    patch settings_order_import_path(import), params: { customer: "hsul", week: "2026-10-21" }
    import.reload
    assert_equal "hsul", ActsAsTenant.with_tenant(company) { import.customer.code }
    assert_equal Date.new(2026, 10, 19), import.week_start
    patch settings_order_import_path(import), params: { status: "applied" }
    assert_equal "applied", import.reload.status
  end

  def applied_serra_import
    upload("pedido_com_unidade.xlsx", "hnorte")
    import = ActsAsTenant.with_tenant(company) { OrderImport.order(:id).last }
    post apply_order_import_path(import)
    import
  end

  def serra_order_state
    ActsAsTenant.with_tenant(company) do
      order = Order.find_by!(customer: Customer.find_by!(code: "hnorte"), week_start: Date.new(2026, 10, 12))
      [ order.lines.group(:product_id, :unit, :delivery_date).sum(:quantity), order.versions.count ]
    end
  end

  test "produção não consegue desfazer importação chamando a rota direto" do
    import = applied_serra_import
    before = serra_order_state

    sign_in_as(user_for(:production))
    post undo_order_import_path(import)

    assert_redirected_to production_path
    assert_equal before, serra_order_state
    assert_equal "applied", ActsAsTenant.with_tenant(company) { import.reload.status }
  end

  test "desfazer importação de outra empresa responde 404 e não muda nada" do
    other = Company.create!(name: "Outra Processadora")
    import = ActsAsTenant.with_tenant(other) do
      customer = Customer.create!(code: "x", name: "Cliente X", short_name: "X")
      OrderImport.create!(customer: customer, filename: "a.xlsx", week_start: Date.new(2026, 10, 12), status: "applied",
                          payload: { "undo" => { "before" => {}, "after" => {}, "aliases" => [] } })
    end

    post undo_order_import_path(import)

    assert_response :not_found
    assert_equal "applied", ActsAsTenant.with_tenant(other) { import.reload.status }
  end

  test "desfazer duas vezes (duplo clique ou F5): a segunda avisa e não grava outra versão" do
    import = applied_serra_import
    post undo_order_import_path(import)
    after_first = serra_order_state

    post undo_order_import_path(import)

    assert_redirected_to order_import_path(import)
    follow_redirect!
    assert_match "Esta importação não pode ser desfeita.", response.body
    assert_equal after_first, serra_order_state
    assert_equal "pending", ActsAsTenant.with_tenant(company) { import.reload.status }
  end

  test "grade recusa quantidade fora da semana: 422, mensagem e nada gravado" do
    product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "cenoura_ralada") }
    before = serra_order_state

    patch orders_path(customer: "hnorte", week: "2026-10-12"), params: { quantities: { "#{product.id}|kg" => { "2026-10-13" => "9", "2026-10-20" => "3" } } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Nada foi salvo/
    assert_select "[role=alert] li", "Cenoura ralada em 20/10: fora da semana do pedido (12/10 a 18/10)."
    assert_equal before, serra_order_state
  end

  # Trocar a semana da importação para uma que não contém as datas da planilha: aplicar é recusado sem gravar
  # nada pela metade (pedido, versão, apelido escolhido e status ficam como estavam).
  test "aplicar com a semana trocada para outra é recusado sem deixar nada pela metade" do
    upload("pedido_sem_unidade.xlsx", "hbp")
    import = ActsAsTenant.with_tenant(company) { OrderImport.order(:id).last }
    patch settings_order_import_path(import), params: { week: "2026-10-19" }
    pitaya = import.reload.rows.index { |r| r["name"].start_with?("Pitaya") }
    product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "abobora_lascas") }
    lines_before = ActsAsTenant.with_tenant(company) { [ OrderLine.count, OrderVersion.count ] }

    post apply_order_import_path(import), params: { mappings: { pitaya.to_s => product.id.to_s } }

    assert_response :unprocessable_entity
    assert_match "fora da semana do pedido (19/10 a 25/10)", response.body
    ActsAsTenant.with_tenant(company) do
      assert_equal lines_before, [ OrderLine.count, OrderVersion.count ]
      assert_not CustomerAlias.exists?(name_in_order: import.rows[pitaya]["name"])
      assert_equal "pending", import.reload.status
    end
  end

  test "arquivo de tipo não aceito volta ao formulário" do
    post order_imports_path, params: { customer: "hbp", file: fixture_file_upload("documento_sem_imagens.odt", "application/vnd.oasis.opendocument.text") }
    assert_response :unprocessable_entity
    assert_match "Não achei imagens", response.body
  end
end
