require "test_helper"

class ApiTokensTest < ActionDispatch::IntegrationTest
  def create_token(name: "ERP", scope: "read")
    post api_tokens_path, params: { api_token: { name: name, scope: scope } }
    response.body[/value="(safra_[^"]+)"/, 1]
  end

  test "admin cria a chave e o token aparece só na resposta da criação" do
    sign_in_as(user_for(:admin))
    plain = create_token(name: "ERP da Hortifruti Modelo")
    assert_response :success
    assert_match "Copie agora", response.body
    assert plain.present?

    token = ActsAsTenant.with_tenant(company) { ApiToken.find_by!(name: "ERP da Hortifruti Modelo") }
    assert_equal ApiToken.digest(plain), token.token_digest
    assert_not_equal plain, token.token_digest
    assert plain.start_with?(token.token_prefix)

    get api_tokens_path
    assert_select "td.name", /ERP da Hortifruti Modelo/
    assert_no_match plain, response.body
    assert_no_match plain, flash.to_h.to_s
  end

  test "a chave criada abre a API da própria empresa, e só no que o acesso permite" do
    sign_in_as(user_for(:admin))
    read_key = create_token(name: "Leitura", scope: "read")
    write_key = create_token(name: "Escrita", scope: "write")
    delete session_path

    get "/api/v1/customers", headers: { "Authorization" => "Bearer #{read_key}" }
    assert_response :success
    assert_includes JSON.parse(response.body)["data"].map { |c| c["code"] }, "hbp"

    put "/api/v1/stock", params: { date: "2026-10-13", counts: [ { raw_material: "cenoura", kg: "5" } ] }, as: :json,
                         headers: { "Authorization" => "Bearer #{read_key}" }
    assert_response :forbidden

    put "/api/v1/stock", params: { date: "2026-10-13", counts: [ { raw_material: "cenoura", kg: "5" } ] }, as: :json,
                         headers: { "Authorization" => "Bearer #{write_key}" }
    assert_response :success
    assert_equal 5, ActsAsTenant.with_tenant(company) { StockCount.find_by!(raw_material: RawMaterial.find_by!(code: "cenoura"), date: "2026-10-13").kg }
  end

  test "revogar derruba a chave na hora e fica no histórico" do
    sign_in_as(user_for(:admin))
    plain = create_token(name: "Velha")
    token = ActsAsTenant.with_tenant(company) { ApiToken.find_by!(name: "Velha") }

    delete api_token_path(token)
    assert_redirected_to api_tokens_path
    assert token.reload.revoked?
    delete session_path

    get "/api/v1/customers", headers: { "Authorization" => "Bearer #{plain}" }
    assert_response :unauthorized
    assert ActsAsTenant.with_tenant(company) { AuditLog.where(auditable_type: "ApiToken").where("auditable_label LIKE ?", "Velha%").exists? }
  end

  test "nome em branco não cria a chave" do
    sign_in_as(user_for(:admin))
    post api_tokens_path, params: { api_token: { name: " ", scope: "read" } }
    assert_response :unprocessable_entity
    assert_equal 0, ActsAsTenant.with_tenant(company) { ApiToken.count }
  end

  test "escritório e produção não acessam as chaves" do
    %i[office production].each do |role|
      sign_in_as(user_for(role))
      get api_tokens_path
      assert_response :redirect, role.to_s
      post api_tokens_path, params: { api_token: { name: "x", scope: "write" } }
      assert_response :redirect, role.to_s
      delete session_path
    end
    assert_equal 0, ActsAsTenant.with_tenant(company) { ApiToken.count }
  end

  test "a sessão do navegador não vale como chave da API" do
    sign_in_as(user_for(:admin))
    get "/api/v1/customers"
    assert_response :unauthorized
  end

  test "a documentação OpenAPI abre para o admin logado e descreve os endpoints" do
    sign_in_as(user_for(:admin))
    get "/api-docs/v1/swagger.yaml"
    assert_response :success
    assert_match "API do Safra", response.body
    assert_match "/api/v1/orders", response.body
    get "/api-docs/index.html"
    assert_response :success
    assert_select "html[lang=pt-BR]"
    assert_select "title", "API do Safra"
    assert_match "Autorizar", response.body
    assert_no_match "fonts.googleapis.com", response.body
  end

  test "sem login a documentação da API não existe" do
    %w[/api-docs /api-docs/index.html /api-docs/v1/swagger.yaml].each do |path|
      get path
      assert_response :not_found, path
    end
  end

  test "escritório e produção não veem a documentação da API" do
    %i[office production].each do |role|
      sign_in_as(user_for(role))
      get "/api-docs/v1/swagger.yaml"
      assert_response :not_found, role
      get "/api-docs/index.html"
      assert_response :not_found, role
    end
  end

  test "admin com senha provisória, desativado ou de empresa suspensa não vê a documentação da API" do
    admin = user_for(:admin)
    sign_in_as(admin)

    admin.update_columns(must_change_password: true)
    get "/api-docs/v1/swagger.yaml"
    assert_response :not_found

    admin.update_columns(must_change_password: false, active: false)
    get "/api-docs/v1/swagger.yaml"
    assert_response :not_found

    admin.update_columns(active: true)
    admin.company.update_columns(active: false)
    get "/api-docs/v1/swagger.yaml"
    assert_response :not_found
  end
end
