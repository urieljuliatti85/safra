require "application_system_test_case"

# Celular de 390 px (driver :mobile_chrome, em application_system_test_case.rb).
class MobileTest < ApplicationSystemTestCase
  driven_by :mobile_chrome

  setup { sign_in_through_form(:admin) }

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
      assert_empty horizontal_scrollers, "#{path} tem área que rola para o lado"
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

  test "na grade de pedidos um dia por vez, sem rolar para o lado, e o que foi digitado em outro dia é salvo junto" do
    visit orders_path(customer: "hnorte", week: "2026-10-12")
    assert_equal 390, page.evaluate_script("document.documentElement.scrollWidth")

    find(".day-pick", text: "Ter 13/10").click
    assert_field "Cenoura ralada em Ter 13/10"
    assert_no_field "Cenoura ralada em Qua 14/10"
    fill_in "Cenoura ralada em Ter 13/10", with: "9,5"

    find(".day-pick", text: "Qua 14/10").click
    assert_no_field "Cenoura ralada em Ter 13/10"
    fill_in "Cenoura ralada em Qua 14/10", with: "4"
    click_on "Salvar pedido"

    assert_text "Pedido salvo"
    assert_field "Cenoura ralada em Qua 14/10", with: "4" # volta no dia em que estava
    find(".day-pick", text: "Ter 13/10").click
    assert_field "Cenoura ralada em Ter 13/10", with: "9,5"
  end

  test "só com pedido mostra os produtos com quantidade no dia escolhido" do
    visit orders_path(customer: "hnorte", week: "2026-10-12")
    find(".day-pick", text: "Qua 14/10").click
    assert_field "Abóbora em cubos em Qua 14/10"
    assert_field "Acelga picada em Qua 14/10"

    assert_text "Só com pedido: só os produtos com quantidade no dia escolhido, para conferir."
    click_on "Só com pedido"
    assert_field "Acelga picada em Qua 14/10", with: "9"
    assert_no_field "Aipim em cubos em Qua 14/10"

    # Todo dia da semana de 12/10 tem pedido do Horizonte Norte; o Horizonte Sul não tem no sábado 17/10.
    visit orders_path(customer: "hsul", week: "2026-10-12")
    find(".day-pick", text: "Sáb 17/10").click
    click_on "Só com pedido"
    assert_text "Nenhum produto com pedido neste dia"
    click_on "Todos"
    assert_field "Abóbora em cubos em Sáb 17/10"
  end

  test "tocar no número da faixa da semana abre a produção do setor já rolada até a lista dele" do
    visit production_path(date: "2026-10-12")
    find("a.bar[aria-label='Cortes manuais, Ter 13/10: 8 itens']").click

    assert_current_path production_path(date: "2026-10-13", sector: "manual")
    assert_selector "#setor-manual h2", text: "Cortes manuais"
    page.document.synchronize do
      top = page.evaluate_script("document.getElementById('setor-manual').getBoundingClientRect().top")
      raise Capybara::ExpectationNotMet, "seção do setor em #{top}px, fora do topo" unless top.between?(0, 100)
    end
  end

  test "semana sem pedido mostra só o aviso da semana, sem mandar tocar em Todos" do
    visit orders_path(customer: "hnorte", week: "2026-11-02")
    assert_text "Nenhum produto nesta semana. Adicione uma linha abaixo."
    assert_no_text "Toque em Todos para digitar"

    click_on "Só com pedido"
    assert_no_text "Toque em Todos para digitar" # sem nenhuma linha, Todos também não teria o que mostrar
  end

  test "os filtros Todos e Só com pedido são botões de ligar e desligar (aria-pressed)" do
    visit orders_path(customer: "hnorte", week: "2026-10-12")
    assert_selector "button[aria-pressed='true']", text: "Todos"
    assert_selector "button[aria-pressed='false']", text: "Só com pedido"

    click_on "Só com pedido"
    assert_selector "button[aria-pressed='true']", text: "Só com pedido"
    assert_selector "button[aria-pressed='false']", text: "Todos"
  end

  test "salvar no celular com dias e linhas escondidos não apaga nem muda o que não foi digitado" do
    before = order_lines("hnorte")
    visit orders_path(customer: "hnorte", week: "2026-10-12")
    find(".day-pick", text: "Qua 14/10").click
    click_on "Só com pedido"
    fill_in "Acelga picada em Qua 14/10", with: "10"
    click_on "Salvar pedido"
    assert_text "Pedido salvo: versão 2, 1 alteração."

    after = order_lines("hnorte")
    assert_equal before.size, after.size
    assert_equal [ [ "Acelga picada", "2026-10-14", "10.0" ] ], (after - before).map { |name, _, date, quantity| [ name, date, quantity ] }
  end

  test "matéria-prima editada no cartão do celular é salva" do
    visit raw_materials_path(filter: "incomplete")
    fill_in "Fator de Cebola", with: "1,1", exact: true
    fill_in "Kg por embalagem de Cebola", with: "20", exact: true
    click_on "Salvar tudo"

    assert_text "1 matéria-prima atualizada."
    cebola = ActsAsTenant.with_tenant(company) { RawMaterial.find_by!(name: "Cebola") }
    assert_equal [ BigDecimal("1.1"), BigDecimal("20") ], [ cebola.reload.multiply_factor, cebola.kg_per_package ]
  end

  private
    # Linhas do pedido da semana de 12/10, para comparar antes e depois de salvar.
    def order_lines(customer_code)
      ActsAsTenant.with_tenant(company) do
        Order.joins(:customer).find_by!(customers: { code: customer_code }, week_start: Date.new(2026, 10, 12))
             .lines.joins(:product).order(:id).pluck("products.name", :unit, :delivery_date, :quantity)
             .map { |name, unit, date, quantity| [ name, unit, date.iso8601, quantity.to_s ] }
      end
    end

    # Elementos com rolagem horizontal própria (tabela larga, faixa da semana) que não cabem na tela.
    def horizontal_scrollers
      page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("main *"))
          .filter((el) => /(auto|scroll)/.test(getComputedStyle(el).overflowX) && el.scrollWidth > el.clientWidth + 1)
          .map((el) => `${el.tagName.toLowerCase()}.${el.className}`)
      JS
    end
end
