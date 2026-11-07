require "application_system_test_case"

class OrderImportsTest < ApplicationSystemTestCase
  setup do
    travel_to Time.zone.local(2026, 10, 5, 9) # antes das 48 h da entrega (R1.26)
    sign_in_through_form(:office)
  end

  # pedido_com_unidade.xlsx muda uma célula do Horizonte Norte: Batata em cubinhos em 15/10, de 1 para 7.
  test "importar uma planilha e desfazer pela grade devolve o pedido ao que era" do
    visit orders_path(customer: "hnorte", week: "2026-10-12")
    assert_field "Batata em cubinhos em Qui 15/10", with: "1"

    click_on "Importar planilha"
    attach_file "Arquivo", file_fixture("pedido_com_unidade.xlsx")
    click_on "Enviar arquivo"
    click_on "Importar no pedido"

    assert_text "Planilha importada no pedido"
    assert_field "Batata em cubinhos em Qui 15/10", with: "7"

    click_on "Desfazer pedido_com_unidade.xlsx"
    accept_confirm { click_on "Desfazer importação" }
    assert_text "Importação desfeita: o pedido de Horiz. Norte voltou ao que era antes."

    visit orders_path(customer: "hnorte", week: "2026-10-12")
    assert_field "Batata em cubinhos em Qui 15/10", with: "1"
    assert_no_link "Desfazer pedido_com_unidade.xlsx"
  end
end
