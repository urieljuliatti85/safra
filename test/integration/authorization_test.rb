require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  FULL = [ "/orders", "/schedule", "/production", "/purchases", "/conference", "/conference/sheets", "/order_imports/new", "/regras" ].freeze

  test "admin e escritório abrem todas as telas de trabalho" do
    %i[admin office].each do |role|
      sign_in_as(user_for(role))
      FULL.each do |path|
        get path
        assert_response :success, "#{role} em #{path}"
      end
    end
  end

  test "só o admin abre a administração de usuários" do
    sign_in_as(user_for(:admin))
    get users_path
    assert_response :success
    sign_in_as(user_for(:office))
    get users_path
    assert_redirected_to orders_path
    follow_redirect!
    assert_match "Você não tem acesso a essa tela", response.body
  end

  test "produção vê programação, produção e PDFs" do
    sign_in_as(user_for(:production))
    [ "/schedule", "/production", "/production.pdf?date=2026-10-13", "/schedule.pdf?date=2026-10-14" ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "produção não vê o botão de enviar aos setores nem consegue enviar" do
    sign_in_as(user_for(:production))
    get production_path(date: "2026-10-13")
    assert_select "button", text: /Enviar aos setores/, count: 0
    assert_no_difference -> { ActsAsTenant.with_tenant(company) { ProductionPlan.count } } do
      post publish_production_path(date: "2026-10-13")
    end
    assert_redirected_to production_path
  end

  test "produção é barrada em pedidos, compras, conferência, importação e usuários" do
    sign_in_as(user_for(:production))
    [ "/orders", "/purchases", "/purchases.pdf?date=2026-10-13", "/conference", "/conference/sheets", "/order_imports/new", "/regras", "/users" ].each do |path|
      get path
      assert_redirected_to production_path, path
    end
    patch orders_path(customer: "hbp", week: "2026-10-12"), params: { quantities: {} }
    assert_redirected_to production_path
    post publish_purchase_path(date: "2026-10-13")
    assert_redirected_to production_path
  end

  test "o menu mostra só o que o papel pode abrir" do
    sign_in_as(user_for(:production))
    get production_path
    assert_select "nav[aria-label='Principal'] a", text: "Programação"
    assert_select "nav[aria-label='Principal'] a", text: "Compras", count: 0
    assert_select "nav[aria-label='Principal'] a", text: "Usuários", count: 0
    sign_in_as(user_for(:admin))
    get orders_path
    assert_select "nav[aria-label='Principal'] a", text: "Usuários"
  end

  test "importação de outra empresa não existe para esta empresa" do
    other = Company.create!(name: "Outra Processadora")
    customer = ActsAsTenant.with_tenant(other) { Customer.create!(code: "x", name: "Cliente X", short_name: "X") }
    import = ActsAsTenant.with_tenant(other) { OrderImport.create!(customer: customer, filename: "a.xlsx", week_start: Date.new(2026, 10, 12)) }
    sign_in_as(user_for(:office))
    get order_import_path(import)
    assert_response :not_found
  end

  test "usuário de outra empresa só vê a própria empresa" do
    other = Company.create!(name: "Outra Processadora")
    user = User.create!(company: other, name: "Admin B", email_address: "admin-b@teste.local", role: "admin", password: "senha-boa-123")
    sign_in_as(user)
    get users_path
    assert_response :success
    assert_select "td.name", text: /Admin B/
    assert_select "td.name", text: /Admin Safra/, count: 0
    get orders_path
    assert_response :success
    assert_match "Nenhum cliente cadastrado", response.body
  end
end
