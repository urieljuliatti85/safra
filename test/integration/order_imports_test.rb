require "test_helper"

class OrderImportsTest < ActionDispatch::IntegrationTest
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

  test "arquivo de tipo não aceito volta ao formulário" do
    post order_imports_path, params: { customer: "hbp", file: fixture_file_upload("documento_sem_imagens.odt", "application/vnd.oasis.opendocument.text") }
    assert_response :unprocessable_entity
    assert_match "Não achei imagens", response.body
  end
end
