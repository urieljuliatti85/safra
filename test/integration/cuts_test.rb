require "test_helper"

class CutsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(user_for(:office))
    ActsAsTenant.current_tenant = company
  end

  teardown { ActsAsTenant.current_tenant = nil }

  test "a lista mostra o corte, o setor, a antecedência e quantos produtos usam" do
    get cuts_path
    assert_response :success
    assert_select "nav[aria-label=Cadastros] a[aria-current=true]", text: "Cortes"
    assert_select "tr", text: /Cubinhos 10x10 mm.*Cubinhos 10×10 mm.*1 dia antes/m
    assert_select "tr", text: /Ralado.*Ralados, picados e rodelas.*No dia da entrega/m
    assert_select "td.num-col", text: /\A\d+\z/
    assert_select ".user-menu a", text: "Histórico", count: 0
  end

  test "criar corte gera o código, usa o nome do setor da empresa e aparece nos produtos" do
    post cuts_path, params: { cut: { name: "Cubos grandes", sector: "manual", lead_days: "2" } }
    assert_redirected_to cuts_path
    cut = Cut.find_by!(name: "Cubos grandes")
    assert_equal [ "cubos_grandes", "Cortes manuais", 2 ], [ cut.code, cut.sector_name, cut.lead_days ]
    follow_redirect!
    assert_match "Corte Cubos grandes criado", response.body
    get new_product_path
    assert_select "select#product_cut_id option", text: "Cubos grandes"
  end

  test "o nome do setor é um só: o que a empresa já usa vale para os cortes novos" do
    Cut.where(sector: "palito").update_all(sector_name: "Palitos finos da casa")
    post cuts_path, params: { cut: { name: "Palito grosso", sector: "palito", lead_days: "1" } }
    assert_equal "Palitos finos da casa", Cut.find_by!(name: "Palito grosso").sector_name
  end

  test "nome repetido (sem diferenciar maiúsculas) ou setor inválido não cria" do
    assert_no_difference -> { Cut.count } do
      post cuts_path, params: { cut: { name: "cubos", sector: "manual", lead_days: "1" } }
      assert_response :unprocessable_entity
      assert_match "Nome já está em uso", response.body
      post cuts_path, params: { cut: { name: "Esquisito", sector: "inexistente", lead_days: "1" } }
      assert_response :unprocessable_entity
      post cuts_path, params: { cut: { name: "Muito cedo", sector: "manual", lead_days: "9" } }
      assert_response :unprocessable_entity
      assert_match "Antecedência deve estar em 0..5", response.body
    end
  end

  test "editar: o código não muda e trocar o setor troca o nome do setor" do
    cut = Cut.create!(name: "Juliana", code: "juliana", sector: "manual", lead_days: 1)
    patch cut_path(cut), params: { cut: { name: "Juliana fina", sector: "ralpic", lead_days: "0" } }
    assert_redirected_to cuts_path
    cut.reload
    assert_equal [ "juliana", "Juliana fina", "ralpic", "Ralados, picados e rodelas", 0 ], [ cut.code, cut.name, cut.sector, cut.sector_name, cut.lead_days ]
  end

  test "a tela de edição avisa quando há produtos no corte" do
    cut = Cut.find_by!(code: "cubinhos")
    get edit_cut_path(cut)
    assert_match "mudar o setor muda a lista de produção", response.body
    assert_select "select#cut_sector option[selected]", "Cubinhos 10×10 mm"
  end

  test "excluir: corte com produtos não exclui, sem produtos exclui" do
    cubos = Cut.find_by!(code: "cubos")
    delete cut_path(cubos)
    follow_redirect!
    assert_match "ainda tem produtos", response.body
    assert Cut.exists?(cubos.id)
    livre = Cut.create!(name: "Sem uso", code: "sem_uso", sector: "manual", lead_days: 1)
    delete cut_path(livre)
    assert_not Cut.exists?(livre.id)
  end

  test "mudar a antecedência pela tela vale para a produção e avisa plano enviado" do
    PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call)
    cubinhos = Cut.find_by!(code: "cubinhos")
    patch cut_path(cubinhos), params: { cut: { name: cubinhos.name, sector: "cubinho", lead_days: "0" } }
    follow_redirect!
    assert_match "mudou desde a versão enviada", response.body
    assert_equal 0, Product.find_by!(code: "baroa_cubinhos").lead_days
  end

  test "um corte novo vira produção: produto e pedido aparecem no setor certo" do
    post cuts_path, params: { cut: { name: "Palito fino", sector: "palito", lead_days: "0" } }
    cut = Cut.find_by!(name: "Palito fino")
    post products_path, params: { product: { name: "Pepino em palito fino", product_group: "processed", raw_material_id: RawMaterial.find_by!(code: "pepino").id, cut_id: cut.id, unit: "kg" } }
    product = Product.find_by!(name: "Pepino em palito fino")
    hbp = Order.joins(:customer).find_by!(customers: { code: "hbp" })
    hbp.lines.create!(product: product, delivery_date: "2026-10-21", quantity: 7, unit: "kg")

    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 21)).call
    assert_equal 7, plan.item_for(product.code).quantity
    get production_path(date: "2026-10-21")
    assert_select "h2", "Palitos"
    assert_select "td.name", text: /Pepino em palito fino/
  end

  test "empresa nova cria cortes além dos padrão sem tocar nos de outra empresa" do
    modelo_cut = Cut.find_by!(code: "cubos")
    result = CompanyOnboarding.new(name: "Padrão SA", admin_name: "Dona", admin_email: "dona@padrao.local").call
    result.admin.update!(must_change_password: false)
    sign_in_as(result.admin)

    get cuts_path
    assert_select "tbody tr", 17
    post cuts_path, params: { cut: { name: "Só nossa", sector: "manual", lead_days: "1" } }
    assert_equal 18, ActsAsTenant.with_tenant(result.company) { Cut.count }
    assert_equal 17, Cut.count, "a empresa de origem não ganha corte"

    get edit_cut_path(modelo_cut)
    assert_response :not_found
    patch cut_path(modelo_cut), params: { cut: { name: "Roubado", sector: "manual", lead_days: "0" } }
    assert_response :not_found
    assert_equal "Cubos", modelo_cut.reload.name
  end

  test "produção não acessa os cortes" do
    sign_in_as(user_for(:production))
    get cuts_path
    assert_redirected_to production_path
    assert_no_difference -> { Cut.count } do
      post cuts_path, params: { cut: { name: "Invasor", sector: "manual", lead_days: "1" } }
    end
  end
end
