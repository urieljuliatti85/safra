require "test_helper"

# A grade usa aria-label nas células (sem <label> visível por célula).
Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]

  # O tour abre sozinho no primeiro acesso; fora do teste do tour, todo mundo já viu.
  setup { User.update_all(tour_seen_at: Time.current) }

  # Entra pelo formulário de login, como a pessoa faria.
  def sign_in_through_form(role = :office)
    visit new_session_path
    fill_in "E-mail", with: DEMO_EMAILS.fetch(role)
    fill_in "Senha", with: DEMO_PASSWORD
    click_on "Entrar"
    assert_no_current_path new_session_path
  end
end
