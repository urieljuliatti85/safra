require "test_helper"

# A grade usa aria-label nas células (sem <label> visível por célula).
Capybara.enable_aria_label = true

# Depois de um envio de formulário a página inteira recarrega; se o Capybara consulta um elemento da página velha nesse
# instante, o ChromeDriver atual responde "Node ... does not belong to the document" (UnknownError) em vez de elemento
# obsoleto. É o mesmo caso: vira StaleElementReferenceError, que o Capybara já trata tentando de novo.
module DetachedNodeAsStale
  private

  def assert_ok
    super
  rescue Selenium::WebDriver::Error::UnknownError => e
    raise unless e.message.include?("does not belong to the document")

    raise Selenium::WebDriver::Error::StaleElementReferenceError, e.message
  end
end
Selenium::WebDriver::Remote::Response.prepend(DetachedNodeAsStale)

# Celular de 390 px num navegador separado: o Chrome headless não abre janela com menos de 500 px, então a tela é
# emulada pelo ChromeDriver. Sessão própria: a largura e o sessionStorage do celular não passam para os outros testes.
# Sem animação: a grade rola até a linha nova com scroll suave (order_lines_controller#focus), e um clique durante a
# rolagem pega o botão fora do lugar e falha às vezes no CI. Com movimento reduzido a rolagem é instantânea.
REDUCED_MOTION = "--force-prefers-reduced-motion".freeze

Capybara.register_driver :mobile_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument(REDUCED_MOTION)
  options.add_emulation(device_metrics: { width: 390, height: 844, pixelRatio: 1, mobile: true, touch: true })
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ] do |options|
    options.add_argument(REDUCED_MOTION)
  end

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
