require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  def log_in(role, password: DEMO_PASSWORD)
    post session_path, params: { email_address: DEMO_EMAILS.fetch(role), password: password }
  end

  test "anônimo vai para o login e volta para a tela pedida depois de entrar" do
    get production_path(date: "2026-10-13")
    assert_redirected_to new_session_path
    log_in(:office)
    assert_redirected_to production_url(date: "2026-10-13")
  end

  test "tela de login em português" do
    get new_session_path
    assert_response :success
    assert_select "h1", "Entrar no Safra"
    assert_select "label", "E-mail"
    assert_select "nav[aria-label='Principal']", false
  end

  test "cada papel cai na sua tela inicial" do
    log_in(:office)
    follow_redirect!
    assert_redirected_to dashboard_path
    delete session_path
    log_in(:production)
    follow_redirect!
    assert_redirected_to production_path
  end

  test "senha errada não entra e mostra a mensagem" do
    log_in(:office, password: "errada-errada")
    assert_redirected_to new_session_path(email_address: DEMO_EMAILS[:office])
    follow_redirect!
    assert_match "E-mail ou senha incorretos", response.body
    get orders_path
    assert_redirected_to new_session_path
  end

  test "e-mail em maiúsculas e com espaços entra do mesmo jeito" do
    post session_path, params: { email_address: "  ESCRITORIO@safra.local ", password: DEMO_PASSWORD }
    assert_redirected_to root_url
  end

  test "usuário desativado não entra" do
    user = User.create!(company: company, name: "Ex", email_address: "ex@teste.local", role: "office", password: "senha-boa-123", active: false)
    post session_path, params: { email_address: user.email_address, password: "senha-boa-123" }
    assert_redirected_to new_session_path(email_address: user.email_address)
  end

  test "sair encerra a sessão" do
    log_in(:office)
    delete session_path
    assert_redirected_to new_session_path
    get orders_path
    assert_redirected_to new_session_path
  end

  test "senha provisória obriga a trocar antes de usar o sistema" do
    user = User.create!(company: company, name: "Nova", email_address: "nova@teste.local", role: "office", password: "provisoria-1", must_change_password: true)
    post session_path, params: { email_address: user.email_address, password: "provisoria-1" }
    get orders_path
    assert_redirected_to edit_account_password_path
    follow_redirect!
    assert_match "Sua senha é provisória", response.body
    assert_select "input[name=current_password]", false

    patch account_password_path, params: { password: "curta", password_confirmation: "curta" }
    assert_response :unprocessable_entity
    assert_match "pelo menos 8 caracteres", response.body
    patch account_password_path, params: { password: "senha-nova-123", password_confirmation: "outra-coisa-1" }
    assert_match "confirmação não é igual", response.body

    patch account_password_path, params: { password: "senha-nova-123", password_confirmation: "senha-nova-123" }
    assert_redirected_to dashboard_path
    assert_not user.reload.must_change_password
    get orders_path
    assert_response :success
  end

  test "trocar a senha pede a atual e derruba os outros aparelhos" do
    log_in(:office)
    other_session = user_for(:office).sessions.create!
    patch account_password_path, params: { current_password: "errada", password: "senha-nova-123", password_confirmation: "senha-nova-123" }
    assert_response :unprocessable_entity
    assert_match "senha atual não confere", response.body

    patch account_password_path, params: { current_password: DEMO_PASSWORD, password: "senha-nova-123", password_confirmation: "senha-nova-123" }
    assert_redirected_to dashboard_path
    assert_not Session.exists?(other_session.id)
    user_for(:office).update!(password: DEMO_PASSWORD) # devolve a senha para os outros testes
  end
end
