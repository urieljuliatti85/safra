require "test_helper"

class UsersAdminTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(user_for(:admin)) }

  test "lista os usuários da empresa" do
    get users_path
    assert_response :success
    assert_select "td.name", text: /Escritório Safra/
    assert_select "td", text: /Escritório/
  end

  test "criar usuário gera senha provisória mostrada uma vez e obriga a trocar" do
    post users_path, params: { user: { name: "Maria", email_address: "maria@teste.local", role: "office" } }
    assert_redirected_to users_path
    follow_redirect!
    password = response.body[/Senha provisória: (\w+) \(/, 1]
    assert_equal 10, password.to_s.length
    user = User.find_by!(email_address: "maria@teste.local")
    assert user.must_change_password
    assert_equal company, user.company
    assert User.authenticate_by(email_address: "maria@teste.local", password: password)
  end

  test "e-mail repetido ou papel inválido não cria" do
    assert_no_difference -> { User.count } do
      post users_path, params: { user: { name: "Dup", email_address: "admin@safra.local", role: "office" } }
      assert_response :unprocessable_entity
      post users_path, params: { user: { name: "X", email_address: "x@teste.local", role: "dono" } }
      assert_response :unprocessable_entity
    end
  end

  test "mudar o papel e desativar derruba as sessões da pessoa" do
    user = User.create!(company: company, name: "Pedro", email_address: "pedro@teste.local", role: "office", password: "senha-boa-123")
    user.sessions.create!
    patch user_path(user), params: { user: { name: "Pedro S.", role: "production", active: "0" } }
    assert_redirected_to users_path
    user.reload
    assert_equal [ "Pedro S.", "production", false ], [ user.name, user.role, user.active ]
    assert_empty user.sessions
  end

  test "redefinir senha gera outra provisória e derruba as sessões" do
    user = User.create!(company: company, name: "Ana", email_address: "ana@teste.local", role: "office", password: "senha-boa-123")
    user.sessions.create!
    post reset_password_user_path(user)
    assert_redirected_to users_path
    assert user.reload.must_change_password
    assert_empty user.sessions
    assert_nil User.authenticate_by(email_address: "ana@teste.local", password: "senha-boa-123")
  end

  test "o admin não muda o próprio papel nem se desativa" do
    me = user_for(:admin)
    patch user_path(me), params: { user: { name: "Admin Safra", role: "office", active: "0" } }
    me.reload
    assert_equal "admin", me.role
    assert me.active
  end

  test "não redefine a própria senha por aqui" do
    post reset_password_user_path(user_for(:admin))
    assert_redirected_to users_path
    assert_not user_for(:admin).must_change_password
  end
end
