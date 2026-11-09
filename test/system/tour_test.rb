require "application_system_test_case"

class TourTest < ApplicationSystemTestCase
  with_guides

  test "o tour abre sozinho no primeiro acesso e só na primeira vez" do
    user_for(:office).update!(tour_seen_at: nil)
    sign_in_through_form(:office)

    assert_current_path orders_path
    within(".tour-card") { assert_text "Passo 1 de 11"; click_on "Sair" }
    assert_no_selector ".tour-card"
    assert user_for(:office).reload.tour_seen_at

    visit production_path
    assert_no_selector ".tour-card"
  end

  test "o botão no canto atravessa as telas do pedido à compra, volta e termina" do
    sign_in_through_form(:office)
    visit production_path
    click_on "Tour guiado"

    assert_current_path orders_path
    within(".tour-card") { assert_text "Passo 1 de 11"; assert_text "Pedidos de cada cliente" }
    assert_selector ".tour-spot"

    click_on "Próximo"
    within(".tour-card") { assert_text "1. Importar a planilha" }
    click_on "Próximo"
    assert_current_path new_order_import_path
    within(".tour-card") { assert_text "Um arquivo por vez" }

    click_on "Voltar"
    assert_current_path orders_path
    within(".tour-card") { assert_text "Passo 2 de 11" }

    (3..11).each do |step|
      within(".tour-card") { click_on "Próximo" }
      assert_selector ".tour-card", text: "Passo #{step} de 11"
    end
    within(".tour-card") { assert_text "Sempre que precisar"; click_on "Concluir" }
    assert_no_selector ".tour-card"

    visit orders_path
    assert_no_selector ".tour-card"
  end

  test "Veja como funciona abre o passo a passo e de lá o tour" do
    sign_in_through_form(:office)
    click_on "Veja como funciona"
    assert_selector "h1", text: "Como funciona"
    assert_selector ".flow-step", count: 7
    click_on "Fazer o tour guiado"
    assert_current_path orders_path
    assert_selector ".tour-card", text: "Passo 1 de 11"
  end

  test "Esc sai do tour e quem é da produção não vê o tour" do
    sign_in_through_form(:office)
    click_on "Tour guiado"
    assert_selector ".tour-card"
    find("body").send_keys(:escape)
    assert_no_selector ".tour-card"

    find("details.user-menu summary").click
    click_on "Sair"
    user_for(:production).update!(tour_seen_at: nil)
    sign_in_through_form(:production)
    assert_no_button "Tour guiado"
    assert_no_selector ".tour-card"
  end
end
