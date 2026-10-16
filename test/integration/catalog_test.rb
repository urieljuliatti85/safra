require "test_helper"

class CatalogTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(user_for(:office))
    ActsAsTenant.current_tenant = company
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def raw_material(code) = RawMaterial.find_by!(code: code)

  # --- matérias-primas (grade em lote) ---

  test "a grade mostra fatores, fornecedores e o que falta" do
    get raw_materials_path
    assert_response :success
    assert_select "h1", "Cadastros"
    assert_select "nav[aria-label=Cadastros] a", 4
    assert_select "input[aria-label='Fator de Cenoura'][value='1,35']"
    assert_select "input[aria-label='Kg por embalagem de Cenoura'][value='20']"
    assert_select "select[aria-label='Fornecedor de Cenoura'] option[selected]", "Fornecedor B"
    assert_select "th a", text: "Cebola"
    assert_match "Compras iguais à planilha", response.body
  end

  test "marca matéria-prima sem fator (processada) e sem kg por embalagem (caixa ou saco)" do
    get raw_materials_path(q: "cebola")
    assert_select "tr", text: /Cebola\b.*sem fator/m
    get raw_materials_path(q: "mamão")
    assert_select ".tag-change", text: "sem kg por embalagem"
    assert_select ".tag-change", text: "sem fator", count: 0 # mamão só é vendido in natura
  end

  test "filtro de incompletas lista só as que precisam de cadastro" do
    get raw_materials_path(filter: "incomplete")
    assert_select "th.sticky-col a", text: "Cebola"
    assert_select "th.sticky-col a", text: "Cenoura", count: 0
    get raw_materials_path(filter: "used")
    assert_select "th.sticky-col a", text: "Cenoura"
  end

  test "salvar em lote atualiza várias linhas, aceita vírgula e avisa quantas mudaram" do
    cebola = raw_material("cebola")
    mamao = raw_material("mamao")
    patch bulk_update_raw_materials_path, params: { raw_materials: {
      cebola.id => { multiply_factor: "1,25", kg_per_package: "20", purchase_package: "sc", supplier_id: cebola.supplier_id },
      mamao.id => { kg_per_package: "6,5", purchase_package: "cx", supplier_id: mamao.supplier_id }
    } }
    assert_redirected_to raw_materials_path
    follow_redirect!
    assert_match "2 matérias-primas atualizadas", response.body
    assert_equal [ 1.25, 20.0 ], cebola.reload.then { |rm| [ rm.multiply_factor.to_f, rm.kg_per_package.to_f ] }
    assert_equal 6.5, mamao.reload.kg_per_package.to_f
  end

  test "preencher o fator tira o aviso de 'sem fator' da compra" do
    antes = PurchasePlanner.new(company: company).call.purchases.values.flatten.select { |n| n.raw_material.code == "cebola" && n.processed_quantity.positive? }
    assert antes.all?(&:missing_factor)
    cebola = raw_material("cebola")
    patch bulk_update_raw_materials_path, params: { raw_materials: { cebola.id => { multiply_factor: "1,3", kg_per_package: "20" } } }
    depois = PurchasePlanner.new(company: company).call.purchases.values.flatten.select { |n| n.raw_material.code == "cebola" && n.processed_quantity.positive? }
    assert depois.none?(&:missing_factor)
    assert depois.all? { |n| n.packages.present? }
  end

  test "campo vazio limpa o valor e linha sem mudança não conta" do
    cenoura = raw_material("cenoura")
    patch bulk_update_raw_materials_path, params: { raw_materials: { cenoura.id => { kg_per_peeled_box: "" } } }
    assert_nil cenoura.reload.kg_per_peeled_box
    patch bulk_update_raw_materials_path, params: { raw_materials: { cenoura.id => { kg_per_peeled_box: "" } } }
    follow_redirect!
    assert_match "Nada mudou", response.body
  end

  test "valor inválido não salva nada, nem as linhas certas, e diz qual" do
    cebola = raw_material("cebola")
    cenoura = raw_material("cenoura")
    patch bulk_update_raw_materials_path, params: { raw_materials: {
      cebola.id => { multiply_factor: "1,3" }, cenoura.id => { multiply_factor: "-2" }
    } }
    assert_response :unprocessable_entity
    assert_match "Cenoura: Fator deve ser maior que 0", response.body
    assert_nil cebola.reload.multiply_factor
    assert_equal 1.35, cenoura.reload.multiply_factor.to_f
  end

  test "fornecedor de outra empresa não vale" do
    other = Company.create!(name: "Outra")
    supplier = ActsAsTenant.with_tenant(other) { Supplier.create!(name: "Alheio") }
    cebola = raw_material("cebola")
    patch bulk_update_raw_materials_path, params: { raw_materials: { cebola.id => { supplier_id: supplier.id } } }
    assert_response :unprocessable_entity
    assert_not_equal supplier.id, cebola.reload.supplier_id
  end

  test "criar matéria-prima gera o código do nome e não repete" do
    post raw_materials_path, params: { raw_material: { name: "Batata roxa", purchase_package: "sc", multiply_factor: "1,4", kg_per_package: "25" } }
    created = RawMaterial.find_by!(name: "Batata roxa")
    assert_equal "batata_roxa", created.code
    assert_equal 1.4, created.multiply_factor.to_f
    post raw_materials_path, params: { raw_material: { name: "Batata roxa", purchase_package: "kg" } }
    assert_equal "batata_roxa_2", RawMaterial.where(name: "Batata roxa").order(:id).last.code
  end

  test "criar sem nome mostra o erro em português" do
    post raw_materials_path, params: { raw_material: { name: "", purchase_package: "kg" } }
    assert_response :unprocessable_entity
    assert_match "Nome não pode ficar em branco", response.body
  end

  test "editar e excluir matéria-prima: com produtos não exclui, sem produtos exclui" do
    cenoura = raw_material("cenoura")
    patch raw_material_path(cenoura), params: { raw_material: { name: "Cenoura", note: "fator conferido" } }
    assert_equal "fator conferido", cenoura.reload.note
    delete raw_material_path(cenoura)
    follow_redirect!
    assert_match "ainda tem produtos", response.body
    assert RawMaterial.exists?(cenoura.id)
    livre = RawMaterial.create!(name: "Livre", code: "livre", purchase_package: "kg")
    delete raw_material_path(livre)
    assert_not RawMaterial.exists?(livre.id)
  end

  # --- produtos ---

  test "lista, busca e filtra produtos por grupo" do
    get products_path(q: "cenoura")
    assert_select "td.name", text: /Cenoura ralada/
    assert_select "td.name", text: /Batata/, count: 0
    get products_path(group: "fruit")
    assert_select "td.name", text: /Laranja descascada/
    assert_select "td.name", text: /Cenoura ralada/, count: 0
  end

  test "criar produto processado exige corte e gera o código" do
    post products_path, params: { product: { name: "Beterraba em palitos finos", product_group: "processed", raw_material_id: raw_material("beterraba").id, unit: "kg" } }
    assert_response :unprocessable_entity
    assert_match "Corte não pode ficar em branco", response.body
    post products_path, params: { product: { name: "Beterraba em palitos finos", product_group: "processed", raw_material_id: raw_material("beterraba").id, cut_id: Cut.find_by!(code: "palitos").id, unit: "kg" } }
    assert_equal "beterraba_em_palitos_finos", Product.find_by!(name: "Beterraba em palitos finos").code
  end

  test "produto in natura ignora o corte e ganha o prefixo in_" do
    post products_path, params: { product: { name: "Jabuticaba", product_group: "raw", raw_material_id: raw_material("cenoura").id, cut_id: Cut.first.id, unit: "kg" } }
    product = Product.find_by!(name: "Jabuticaba")
    assert_equal "in_jabuticaba", product.code
    assert_nil product.cut_id
  end

  test "editar produto e excluir: com pedidos não exclui" do
    product = Product.find_by!(code: "cenoura_ralada")
    patch product_path(product), params: { product: { name: "Cenoura ralada fina", product_group: "processed", raw_material_id: product.raw_material_id, cut_id: product.cut_id, unit: "kg" } }
    assert_equal "Cenoura ralada fina", product.reload.name
    assert_equal "cenoura_ralada", product.code
    delete product_path(product)
    follow_redirect!
    assert_match "já tem linhas de pedido", response.body
    livre = Product.create!(name: "Sem pedido", code: "sem_pedido", product_group: "processed", raw_material: raw_material("cenoura"), cut: product.cut, unit: "kg")
    delete product_path(livre)
    assert_not Product.exists?(livre.id)
  end

  # --- clientes e apelidos ---

  test "criar cliente gera o código e leva para os apelidos" do
    post customers_path, params: { customer: { name: "Restaurante Novo Ltda", short_name: "Novo", order_source: "xlsx" } }
    customer = Customer.find_by!(name: "Restaurante Novo Ltda")
    assert_equal "novo", customer.code
    assert_redirected_to edit_customer_path(customer)
  end

  test "apelidos: adicionar, repetido dá erro e remover" do
    customer = Customer.find_by!(code: "hbp")
    product = Product.find_by!(code: "cenoura_ralada")
    post customer_customer_aliases_path(customer), params: { customer_alias: { name_in_order: "Cenoura Fininha Ralada", product_id: product.id } }
    assert_redirected_to edit_customer_path(customer, anchor: "apelidos")
    record = customer.aliases.find_by!(name_in_order: "Cenoura Fininha Ralada")
    follow_redirect!
    assert_match "Cenoura Fininha Ralada", response.body
    post customer_customer_aliases_path(customer), params: { customer_alias: { name_in_order: "Cenoura Fininha Ralada", product_id: product.id } }
    follow_redirect!
    assert_match "Nome no pedido já está em uso", response.body
    delete customer_customer_alias_path(customer, record)
    assert_not CustomerAlias.exists?(record.id)
  end

  test "a importação passa a reconhecer o apelido cadastrado na tela" do
    customer = Customer.find_by!(code: "hbp")
    product = Product.find_by!(code: "abobora_lascas")
    post customer_customer_aliases_path(customer), params: { customer_alias: { name_in_order: "Pitaya Fatiada Especial", product_id: product.id } }
    import = OrderImports::Importer.new(company: company, customer: customer, path: file_fixture("pedido_sem_unidade.xlsx").to_s, filename: "x.xlsx").call
    assert_equal product.id, import.rows.find { |r| r["name"].start_with?("Pitaya") }["product_id"]
  end

  test "cliente com pedidos não exclui; sem pedidos exclui" do
    hbp = Customer.find_by!(code: "hbp")
    delete customer_path(hbp)
    follow_redirect!
    assert_match "já tem pedidos", response.body
    assert Customer.exists?(hbp.id)
    novo = Customer.create!(code: "tmp", name: "Temp", short_name: "Temp")
    delete customer_path(novo)
    assert_not Customer.exists?(novo.id)
  end

  # --- fornecedores ---

  test "fornecedor: criar, editar e excluir (com matérias-primas não exclui)" do
    post suppliers_path, params: { supplier: { name: "Novo Atacado" } }
    supplier = Supplier.find_by!(name: "Novo Atacado")
    patch supplier_path(supplier), params: { supplier: { name: "Novo Atacado SA" } }
    assert_equal "Novo Atacado SA", supplier.reload.name
    delete supplier_path(supplier)
    assert_not Supplier.exists?(supplier.id)

    fornecedor = Supplier.find_by!(name: "Fornecedor B")
    delete supplier_path(fornecedor)
    follow_redirect!
    assert_match "ainda tem matérias-primas", response.body
    assert Supplier.exists?(fornecedor.id)
  end

  test "fornecedor repetido não cria" do
    post suppliers_path, params: { supplier: { name: "Fornecedor B" } }
    assert_response :unprocessable_entity
    assert_match "Nome já está em uso", response.body
  end

  # --- acesso e isolamento ---

  test "produção é barrada em todos os cadastros" do
    sign_in_as(user_for(:production))
    [ raw_materials_path, products_path, customers_path, suppliers_path, new_product_path, new_raw_material_path ].each do |path|
      get path
      assert_redirected_to production_path, path
    end
    cebola = raw_material("cebola")
    patch bulk_update_raw_materials_path, params: { raw_materials: { cebola.id => { multiply_factor: "9" } } }
    assert_redirected_to production_path
    assert_nil cebola.reload.multiply_factor
  end

  test "registro de outra empresa não existe para esta empresa" do
    other = Company.create!(name: "Outra")
    rm = ActsAsTenant.with_tenant(other) { RawMaterial.create!(name: "Alheia", code: "alheia", purchase_package: "kg") }
    get edit_raw_material_path(rm)
    assert_response :not_found
    patch bulk_update_raw_materials_path, params: { raw_materials: { rm.id => { multiply_factor: "9" } } }
    assert_nil ActsAsTenant.with_tenant(other) { rm.reload.multiply_factor }
  end

  test "o menu leva aos cadastros" do
    get orders_path
    assert_select "nav[aria-label='Principal'] a", text: "Cadastros"
  end
end
