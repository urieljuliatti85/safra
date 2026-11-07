require "test_helper"

class CompaniesTest < ActionDispatch::IntegrationTest
  setup { ActsAsTenant.current_tenant = company }
  teardown { ActsAsTenant.current_tenant = nil }

  def create_company(name: "Atacado Novo", email: "dono@novo.local", catalog: "standard")
    post companies_path, params: { name: name, admin_name: "Dona Nova", admin_email: email, catalog_from: catalog }
  end

  def password_from_flash
    follow_redirect!
    response.body[/senha provisória: (\w+) /, 1]
  end

  # --- acesso ---

  test "só o dono da plataforma abre as empresas" do
    sign_in_as(user_for(:admin))
    get companies_path
    assert_response :success
    assert_select "h1", "Empresas"
    assert_select ".user-menu a", text: "Empresas"

    %i[office production].each do |role|
      sign_in_as(user_for(role))
      get companies_path
      assert_response :redirect
      assert_no_match(/Nova empresa/, response.body)
    end
  end

  test "administrador de empresa que não é dono da plataforma não cria empresa" do
    other = Company.create!(name: "Outra")
    boss = User.create!(company: other, name: "Chefe", email_address: "chefe@outra.local", role: "admin", password: "senha-boa-123")
    sign_in_as(boss)
    get companies_path
    assert_redirected_to dashboard_path
    assert_no_difference -> { Company.count } do
      post companies_path, params: { name: "Invasora", admin_name: "X", admin_email: "x@x.local", catalog_from: "standard" }
    end
    get users_path
    assert_select ".user-menu a", text: "Empresas", count: 0
  end

  # --- criar ---

  test "criar com os cortes padrão: administrador com senha provisória e empresa vazia" do
    sign_in_as(user_for(:admin))
    create_company
    new_company = Company.find_by!(name: "Atacado Novo")
    assert_redirected_to companies_path
    password = password_from_flash
    assert_match(/\A\w{10}\z/, password)
    admin = new_company.users.sole
    assert_equal [ "admin", true, false, "dono@novo.local" ], [ admin.role, admin.must_change_password, admin.platform_admin, admin.email_address ]
    ActsAsTenant.with_tenant(new_company) do
      assert_equal 17, Cut.count
      assert_equal [ 0, 0, 0, 0 ], [ Customer.count, Product.count, RawMaterial.count, Order.count ]
    end
    assert User.authenticate_by(email_address: "dono@novo.local", password: password)
  end

  test "copiar o catálogo traz fatores, produtos e exceções, e nada da operação" do
    ProductionRule.create!(product: Product.find_by!(code: "batata_cubos"), lead_days: 0)
    company.update!(raw_lead_days: 2)
    sign_in_as(user_for(:admin))
    create_company(name: "Cópia SA", email: "copia@novo.local", catalog: company.id)
    copy = Company.find_by!(name: "Cópia SA")
    ActsAsTenant.with_tenant(copy) do
      assert_equal [ 70, 120, 10, 17, 1, 14 ], [ RawMaterial.count, Product.count, Supplier.count, Cut.count, ProductionRule.count, ProductComponent.count ]
      cenoura = RawMaterial.find_by!(code: "cenoura")
      assert_equal [ 1.35, 20.0, "Fornecedor B" ], [ cenoura.multiply_factor.to_f, cenoura.kg_per_package.to_f, cenoura.supplier.name ]
      produto = Product.find_by!(code: "cenoura_ralada")
      assert_equal copy.id, produto.raw_material.company_id
      assert_equal copy.id, produto.cut.company_id
      assert_equal 0, Product.find_by!(code: "batata_cubos").lead_days
      assert_equal [ 0, 0, 0, 0, 0, 0 ], [ Customer.count, CustomerAlias.count, Order.count, OrderLine.count, StockCount.count, PurchaseDay.count ]
    end
    assert_equal 2, copy.raw_lead_days
    assert_equal 70, RawMaterial.count, "a empresa de origem não pode mudar"
  end

  test "a montagem inicial não enche o histórico da empresa nova" do
    sign_in_as(user_for(:admin))
    create_company(name: "Sem Ruído SA", email: "ruido@novo.local", catalog: company.id)
    copy = Company.find_by!(name: "Sem Ruído SA")
    assert_equal 0, ActsAsTenant.with_tenant(copy) { AuditLog.count }
    assert AuditLog.where(auditable_type: "Company", action: "create").exists?, "a criação da empresa fica no histórico de quem criou"
  end

  test "e-mail repetido ou nome em branco não cria nada" do
    sign_in_as(user_for(:admin))
    assert_no_difference [ -> { Company.count }, -> { User.count } ] do
      create_company(name: "Duplicada", email: "admin@safra.local")
      assert_response :unprocessable_entity
      assert_match "Administrador: E-mail já está em uso", response.body
      create_company(name: "", email: "novo@x.local")
      assert_response :unprocessable_entity
      assert_match "Empresa: Nome não pode ficar em branco", response.body
    end
  end

  # --- isolamento ---

  test "o administrador da empresa nova só enxerga a própria empresa" do
    sign_in_as(user_for(:admin))
    create_company(name: "Isolada SA", email: "iso@novo.local", catalog: company.id)
    provisional = password_from_flash
    delete session_path
    post session_path, params: { email_address: "iso@novo.local", password: provisional }
    follow_redirect!
    assert_redirected_to edit_account_password_path # senha provisória: troca antes de tudo
    patch account_password_path, params: { password: "senha-do-dono-1", password_confirmation: "senha-do-dono-1" }

    get orders_path
    assert_match "Nenhum cliente cadastrado em Isolada SA", response.body
    get users_path
    assert_select "td.name", text: /Dona Nova/
    assert_select "td.name", text: /Admin Safra/, count: 0
    outro_produto = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "cenoura_ralada") }
    get edit_product_path(outro_produto)
    assert_response :not_found
    get audit_logs_path
    assert_no_match(/Admin Safra/, response.body)
    get companies_path
    assert_redirected_to dashboard_path
  end

  # --- suspender ---

  test "renomear e suspender: ninguém entra e as sessões caem; reativar devolve o acesso" do
    sign_in_as(user_for(:admin))
    create_company(name: "Suspensa SA", email: "susp@novo.local")
    target = Company.find_by!(name: "Suspensa SA")
    admin = target.users.sole
    admin.update!(password: "senha-do-dono-1", must_change_password: false)
    open_session = admin.sessions.create!

    patch company_path(target), params: { company: { name: "Suspensa Ltda", active: "0" } }
    assert_redirected_to companies_path
    assert_equal [ "Suspensa Ltda", false ], target.reload.then { |c| [ c.name, c.active ] }
    assert_not Session.exists?(open_session.id)

    delete session_path
    post session_path, params: { email_address: "susp@novo.local", password: "senha-do-dono-1" }
    assert_redirected_to new_session_path(email_address: "susp@novo.local")
    failed = ActsAsTenant.with_tenant(target) { AuditLog.where(action: "login_failed").newest_first.first }
    assert_equal [ nil, "empresa suspensa" ], failed.details["Motivo"]

    sign_in_as(user_for(:admin))
    patch company_path(target), params: { company: { name: "Suspensa Ltda", active: "1" } }
    assert target.reload.active
    delete session_path
    post session_path, params: { email_address: "susp@novo.local", password: "senha-do-dono-1" }
    assert_redirected_to root_url
  end

  test "sessão antiga de empresa suspensa não vale mais" do
    other = Company.create!(name: "Sessão SA")
    user = User.create!(company: other, name: "Pessoa", email_address: "pessoa@sessao.local", role: "office", password: "senha-boa-123")
    sign_in_as(user)
    other.update_columns(active: false) # suspensão por fora, sem derrubar a sessão
    get orders_path
    assert_redirected_to new_session_path
  end

  test "não suspende a própria empresa" do
    sign_in_as(user_for(:admin))
    patch company_path(company), params: { company: { name: company.name, active: "0" } }
    assert_response :unprocessable_entity
    assert_match "não pode suspender a empresa em que você mesmo trabalha", response.body
    assert company.reload.active
  end

  # --- dono da plataforma ---

  test "ninguém vira dono da plataforma pela tela de usuários" do
    sign_in_as(user_for(:admin))
    post users_path, params: { user: { name: "Maria", email_address: "maria@teste.local", role: "office", platform_admin: "1" } }
    assert_not User.find_by!(email_address: "maria@teste.local").platform_admin
    maria = User.find_by!(email_address: "maria@teste.local")
    patch user_path(maria), params: { user: { name: "Maria", role: "office", active: "1", platform_admin: "1" } }
    assert_not maria.reload.platform_admin
  end

  test "a lista mostra usuários, clientes e produtos de cada empresa sem abrir os dados" do
    sign_in_as(user_for(:admin))
    get companies_path
    assert_select "td.name", text: /Hortifruti Modelo/
    assert_match "(a sua)", response.body
    assert_select "tr", text: /Hortifruti Modelo.*Ativa.*3.*7.*120/m
  end
end
