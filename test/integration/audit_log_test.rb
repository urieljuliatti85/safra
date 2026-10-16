require "test_helper"

class AuditLogTest < ActionDispatch::IntegrationTest
  setup { ActsAsTenant.current_tenant = company }
  teardown { ActsAsTenant.current_tenant = nil }

  def logs(scope = AuditLog.all) = scope.newest_first.to_a

  # --- o que vira registro ---

  test "salvar em lote registra cada linha mudada e agrupa pela mesma ação" do
    sign_in_as(user_for(:office))
    cebola = RawMaterial.find_by!(code: "cebola")
    mamao = RawMaterial.find_by!(code: "mamao")
    patch bulk_update_raw_materials_path, params: { raw_materials: { cebola.id => { multiply_factor: "1,3" }, mamao.id => { kg_per_package: "6,5" } } }
    created = logs(AuditLog.where(auditable_type: "RawMaterial"))
    assert_equal 2, created.size
    assert_equal 1, created.map(&:request_id).uniq.size
    assert created.all? { |l| l.user_name == "Escritório Safra" && l.action == "update" }
  end

  test "entrar, sair e senha errada ficam no histórico da pessoa" do
    post session_path, params: { email_address: DEMO_EMAILS[:office], password: "errada-errada" }
    post session_path, params: { email_address: DEMO_EMAILS[:office], password: DEMO_PASSWORD }
    delete session_path
    assert_equal %w[logout login login_failed], logs(AuditLog.where(user: user_for(:office))).map(&:action).first(3)
    failed = AuditLog.find_by!(action: "login_failed")
    assert_equal [ nil, "senha incorreta" ], failed.details["Motivo"]
  end

  test "e-mail desconhecido não gera registro (não há empresa)" do
    assert_no_difference -> { AuditLog.count } do
      post session_path, params: { email_address: "ninguem@teste.local", password: "x" }
    end
  end

  test "trocar a própria senha registra o evento sem a senha" do
    sign_in_as(user_for(:office))
    patch account_password_path, params: { current_password: DEMO_PASSWORD, password: "nova-senha-123", password_confirmation: "nova-senha-123" }
    assert_equal "password_changed", logs.first.action
    assert_not_includes AuditLog.all.map { |l| l.details.to_json }.join, "nova-senha"
    user_for(:office).update!(password: DEMO_PASSWORD)
  end

  test "administração de usuários, regras, estoque e importação aparecem com quem fez" do
    sign_in_as(user_for(:admin))
    post users_path, params: { user: { name: "Maria", email_address: "maria@teste.local", role: "office" } }
    patch rules_path, params: { commit_action: "save", cut_leads: { Cut.find_by!(code: "cubinhos").id => "0" } }
    patch stock_path, params: { date: "2026-10-12", counts: { RawMaterial.find_by!(code: "cenoura").id => "12,5" } }
    types = AuditLog.where(user: user_for(:admin)).pluck(:auditable_type).uniq
    assert_includes types, "User"
    assert_includes types, "Cut"
    assert_includes types, "StockCount"
    cut_log = AuditLog.where(auditable_type: "Cut").newest_first.first
    assert_equal [ "1", "0" ], cut_log.details["Antecedência"]
  end

  test "ver efeito (simulação de regras) não deixa registro" do
    sign_in_as(user_for(:office))
    assert_no_difference -> { AuditLog.where(auditable_type: "Cut").count } do
      patch rules_path, params: { commit_action: "simulate", cut_leads: { Cut.find_by!(code: "cubinhos").id => "0" } }
    end
  end

  test "enviar produção e aplicar importação ficam registrados" do
    sign_in_as(user_for(:office))
    post publish_production_path(date: "2026-10-13")
    assert_equal "ProductionPlan", logs.first.auditable_type
    assert_equal "Produção de 13/10/2026 v1", logs.first.auditable_label
  end

  # --- a tela ---

  test "só o administrador abre o histórico" do
    sign_in_as(user_for(:office))
    get audit_logs_path
    assert_redirected_to orders_path
    sign_in_as(user_for(:production))
    get audit_logs_path
    assert_redirected_to production_path
    sign_in_as(user_for(:admin))
    get audit_logs_path
    assert_response :success
    assert_select "h1", "Histórico"
    assert_select ".user-menu a", text: "Histórico"
  end

  test "mostra quem, quando e o antes e depois; o salvar em lote vira uma ação só" do
    sign_in_as(user_for(:office))
    cebola = RawMaterial.find_by!(code: "cebola")
    mamao = RawMaterial.find_by!(code: "mamao")
    patch bulk_update_raw_materials_path, params: { raw_materials: { cebola.id => { multiply_factor: "1,3" }, mamao.id => { kg_per_package: "6,5" } } }
    sign_in_as(user_for(:admin))
    get audit_logs_path(type: "RawMaterial")
    assert_response :success
    assert_select "details.panel", 1
    assert_match "Escritório Safra", response.body
    assert_match "alterou 2 matérias-primas", response.body
    assert_match "Fator: 1,3", response.body
    assert_match "Kg por embalagem: 6,5", response.body
  end

  test "filtra por quem, por tipo, por nome e por data" do
    sign_in_as(user_for(:office))
    patch bulk_update_raw_materials_path, params: { raw_materials: { RawMaterial.find_by!(code: "cebola").id => { multiply_factor: "1,3" } } }
    sign_in_as(user_for(:admin))
    patch rules_path, params: { commit_action: "save", cut_leads: { Cut.find_by!(code: "cubinhos").id => "0" } }

    get audit_logs_path(user_id: user_for(:office).id, type: "RawMaterial")
    assert_match "Cebola", response.body
    assert_select "details.panel", 1
    get audit_logs_path(user_id: user_for(:admin).id, type: "RawMaterial")
    assert_match "Nada no histórico com esses filtros", response.body
    get audit_logs_path(q: "cubinhos")
    assert_match "Cubinhos", response.body
    get audit_logs_path(from: (Date.current + 1).iso8601)
    assert_match "Nada no histórico", response.body
    get audit_logs_path(from: Date.current.iso8601, to: Date.current.iso8601)
    assert_select "details.panel"
  end

  test "histórico de um cadastro só, a partir da tela de edição" do
    sign_in_as(user_for(:admin))
    cebola = RawMaterial.find_by!(code: "cebola")
    patch raw_material_path(cebola), params: { raw_material: { name: "Cebola", multiply_factor: "1,3" } }
    patch raw_material_path(RawMaterial.find_by!(code: "mamao")), params: { raw_material: { name: "Mamão", note: "x" } }
    get edit_raw_material_path(cebola)
    assert_select "a[href='#{audit_logs_path(type: 'RawMaterial', id: cebola.id)}']", text: "Histórico deste cadastro"
    get audit_logs_path(type: "RawMaterial", id: cebola.id)
    assert_match "Só deste cadastro", response.body
    assert_match "Fator: 1,3", response.body
    assert_no_match(/Mamão/, response.body)
  end

  test "pagina por ação" do
    sign_in_as(user_for(:admin))
    Current.session = user_for(:admin).sessions.create!
    35.times { |i| Current.request_id = "r#{i}"; StockCount.create!(raw_material: RawMaterial.first, date: Date.new(2027, 1, 1) + i, kg: i) }
    Current.reset
    get audit_logs_path
    assert_match "Página 1 de 2", response.body
    assert_select "details.panel", AuditTrail::PER_PAGE
    get audit_logs_path(page: 2)
    assert_select "details.panel", 35 - AuditTrail::PER_PAGE
    assert_select "nav[aria-label='Páginas'] a", text: "Anterior"
  end

  test "histórico de outra empresa não aparece" do
    other = Company.create!(name: "Outra")
    admin_b = User.create!(company: other, name: "Admin B", email_address: "b@teste.local", role: "admin", password: "senha-boa-123")
    ActsAsTenant.with_tenant(other) do
      Current.session = admin_b.sessions.create!
      Supplier.create!(name: "Segredo de B")
      Current.reset
    end
    sign_in_as(user_for(:admin))
    get audit_logs_path
    assert_no_match(/Segredo de B/, response.body)
  end
end
