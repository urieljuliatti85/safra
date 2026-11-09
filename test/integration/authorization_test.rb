require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  FULL = [ "/painel", "/orders", "/schedule", "/production", "/purchases", "/conference", "/conference/sheets", "/conference/sheets/import", "/order_imports/new", "/regras", "/estoque" ].freeze

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
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match "Você não tem acesso a essa tela", response.body
  end

  test "produção vê programação, produção, estoque e PDFs" do
    sign_in_as(user_for(:production))
    [ "/schedule", "/production", "/estoque", "/production.pdf?date=2026-10-13", "/schedule.pdf?date=2026-10-14" ].each do |path|
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

  test "produção vê a versão enviada, não o cálculo que o escritório ainda não enviou" do
    sign_in_as(user_for(:production))
    get production_path(date: "2026-10-13")
    assert_select "td", text: "Cenoura ralada", count: 0
    assert_match "O escritório ainda não enviou a produção", response.body

    ActsAsTenant.with_tenant(company) do
      PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call)
      OrderLine.joins(:product).find_by!(products: { code: "cenoura_ralada" }, delivery_date: Date.new(2026, 10, 13)).increment!(:quantity, 4)
    end
    get production_path(date: "2026-10-13")
    assert_select "tr", text: /Cenoura ralada/ do
      assert_select "td.qty", "3"
    end
    assert_select ".tag-change", count: 0
    assert_match "O escritório tem alterações ainda não enviadas", response.body
    get production_path(date: "2026-10-13", format: :pdf)
    assert_response :success

    sign_in_as(user_for(:office))
    get production_path(date: "2026-10-13")
    assert_select "tr", text: /Cenoura ralada/ do
      assert_select "td.qty", "7"
    end
    assert_match "Mudou depois do envio", response.body
  end

  test "histórico de envios: setores veem cada versão, o que mudou e a que vale" do
    date = Date.new(2026, 10, 13)
    sign_in_as(user_for(:office))
    post publish_production_path(date: date)
    ActsAsTenant.with_tenant(company) do
      OrderLine.joins(:product).find_by!(products: { code: "cenoura_ralada" }, delivery_date: date).increment!(:quantity, 4)
    end
    post publish_production_path(date: date)
    first, second = ActsAsTenant.with_tenant(company) { ProductionPlan.where(date: date).order(:version).to_a }
    assert_equal user_for(:office), second.sent_by

    sign_in_as(user_for(:production))
    get production_path(date: date)
    assert_select "#envios a", text: "v2"
    assert_select "#envios a", text: "v1"
    assert_match "1 mudança em relação à v1", response.body
    assert_match "O que mudou da v1 para a v2", response.body
    assert_select "tr.is-changed", text: /Cenoura ralada/

    get production_version_path(first)
    assert_response :success
    assert_match "Substituída", response.body
    assert_select "tr", text: /Cenoura ralada/ do
      assert_select "td.qty", "3"
    end
    get production_version_path(second)
    assert_match "Vale esta versão", response.body
    assert_match "Cenoura ralada</strong>: 3 → 7", response.body
    get production_version_path(first, format: :pdf)
    assert_equal "application/pdf", response.media_type
  end

  test "produção é barrada em pedidos, compras, conferência, importação e usuários" do
    sign_in_as(user_for(:production))
    [ "/orders", "/purchases", "/purchases.pdf?date=2026-10-13", "/conference", "/conference/sheets", "/conference/sheets/import", "/order_imports/new", "/regras", "/painel", "/users", "/historico" ].each do |path|
      get path
      assert_redirected_to production_path, path
    end
    patch orders_path(customer: "hbp", week: "2026-10-12"), params: { entry_type: "alteration", quantities: {} }
    assert_redirected_to production_path
    post publish_purchase_path(date: "2026-10-13")
    assert_redirected_to production_path
  end

  test "o menu mostra só o que o papel pode abrir" do
    sign_in_as(user_for(:production))
    get production_path
    assert_select "nav[aria-label='Principal'] a", text: "Programação"
    assert_select "nav[aria-label='Principal'] a", text: "Compras", count: 0
    assert_select ".user-menu a", text: "Usuários", count: 0
    sign_in_as(user_for(:admin))
    get orders_path
    assert_select ".user-menu a", text: "Usuários"
    assert_select ".user-menu a", text: "Histórico"
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

  test "como funciona e tour ficam escondidos com a chave desligada" do
    office = user_for(:office)
    office.update!(tour_seen_at: nil)
    sign_in_as(office)
    get orders_path
    assert_select "body[data-controller='tour']", count: 0
    assert_select "a.guide-link", count: 0
    get guide_path
    assert_redirected_to root_path
  end

  test "tour: escritório marca que já viu; produção não tem tour" do
    Rails.configuration.x.guides_enabled = true
    office = user_for(:office)
    office.update!(tour_seen_at: nil)
    sign_in_as(office)
    get orders_path
    assert_select "body[data-tour-autostart-value='true']"
    assert_no_difference -> { ActsAsTenant.with_tenant(company) { AuditLog.count } } do
      post tour_path
    end
    assert_response :no_content
    assert office.reload.tour_seen_at
    get orders_path
    assert_select "body[data-tour-autostart-value='false']"
    assert_select "button.tour-tab", "Tour guiado"
    assert_select ".guide-bar a.guide-link[href='/como-funciona']", /Veja como funciona/

    production = user_for(:production)
    production.update!(tour_seen_at: nil)
    sign_in_as(production)
    get production_path
    assert_select "body[data-controller='tour']", count: 0
    assert_select "a.guide-link", count: 0
    get guide_path
    assert_redirected_to production_path
    post tour_path
    assert_nil production.reload.tour_seen_at
  ensure
    Rails.configuration.x.guides_enabled = false
  end
end
