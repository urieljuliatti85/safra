require "application_system_test_case"

# Celular de 390 px. O Chrome headless não abre janela com menos de 500 px, por isso a largura é emulada.
class MobileTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    sign_in_through_form(:admin)
  end

  # A sessão do Chrome é a mesma para todos os testes de sistema: sem isso os seguintes rodariam em 390 px.
  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "nenhuma tela passa da largura do celular" do
    [
      dashboard_path(date: "2026-10-13"), orders_path(week: "2026-10-12"), schedule_path(date: "2026-10-13"),
      production_path(date: "2026-10-13"), purchases_path(date: "2026-10-13"), stock_path(date: "2026-10-13"),
      indicators_path, conference_path, conference_sheets_path, rules_path, suppliers_path, raw_materials_path,
      products_path, cuts_path, customers_path, audit_logs_path, companies_path, users_path, api_tokens_path, guide_path
    ].each do |path|
      visit path
      assert_selector ".tabbar"
      assert_equal 390, page.evaluate_script("document.documentElement.scrollWidth"), "#{path} passa da largura do celular"
    end
  end

  test "as telas do dia a dia são abas embaixo e as outras ficam em Mais" do
    visit orders_path(week: "2026-10-12")
    assert_no_selector ".shell-nav .nav-links"

    within(".tabbar") { click_on "Compras" }
    assert_current_path purchases_path
    assert_selector ".tabbar a[aria-current='page']", text: "Compras"

    within(".tabbar") { find("summary", text: "Mais").click; click_on "Estoque" }
    assert_current_path stock_path
    assert_selector ".tabbar summary.is-current", text: "Mais"
  end

  test "no estoque cada matéria-prima é um cartão com a contagem e o que comprar à vista" do
    visit stock_path(date: "2026-10-12")
    within(".stock-sheet tbody tr", text: "Cenoura") do
      assert_field "Contagem de Cenoura"
      cell = find("td[data-label='Comprar']")
      assert_operator page.evaluate_script("arguments[0].getBoundingClientRect().right", cell), :<=, 390
    end
    assert_equal 390, page.evaluate_script("document.documentElement.scrollWidth")
  end

  test "no pedido o cliente é escolhido num select acima do título, sem as pílulas" do
    visit orders_path(customer: "hnorte", week: "2026-10-12")
    assert_no_selector ".chip", text: "Bom Pastor"
    select "Bom Pastor", from: "Escolha o cliente:"

    assert_selector "h1", text: "Hospital Bom Pastor"
    assert_text "Semana de 12/10"
    assert_select "Escolha o cliente:", selected: "Bom Pastor"
  end
end
