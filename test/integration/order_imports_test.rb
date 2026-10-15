require "test_helper"

class OrderImportsTest < ActionDispatch::IntegrationTest
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
    assert_equal "applied", ActsAsTenant.with_tenant(company) { import.reload.status }
  end


  test "sem arquivo não envia" do
    post order_imports_path, params: { customer: "hbp" }
    assert_response :unprocessable_entity
    assert_match "Escolha o cliente e a planilha", response.body
  end
end
