require "application_system_test_case"

class OrdersTest < ApplicationSystemTestCase
  setup { sign_in_through_form(:office) }

  test "no computador os clientes são pílulas, sem o select do celular" do
    visit orders_path(customer: "hnorte", week: "2026-10-12")
    assert_no_field "Escolha o cliente:"
    click_on "Bom Pastor"

    assert_selector "h1", text: "Hospital Bom Pastor"
    assert_text "Semana de 12/10"
    assert_selector ".chip[aria-current='true']", text: "Bom Pastor"
  end

  test "digitar um pedido na grade e salvar" do
    visit orders_path(customer: "hnorte", week: "2026-10-12")
    assert_selector "h1", text: "Hospital Horizonte Norte"

    fill_in "Cenoura ralada em Ter 13/10", with: "9,5"
    click_on "Salvar pedido"

    assert_text "Pedido salvo: versão 2, 1 alteração."
    assert_field "Cenoura ralada em Ter 13/10", with: "9,5"
  end

  test "texto inválido na grade não salva e aponta a célula" do
    visit orders_path(customer: "hnorte", week: "2026-10-12")

    fill_in "Cenoura ralada em Ter 13/10", with: "5 + 2"
    click_on "Salvar pedido"

    assert_text "Nada foi salvo"
    assert_text "não é um número"
  end

  test "produção do dia mostra setores e envia aos setores" do
    visit production_path(date: "2026-10-13")
    assert_selector "h2", text: "Ralados, picados e rodelas"

    click_on "Enviar aos setores"
    assert_text "enviada aos setores (versão 1)"
    assert_text "Igual ao que foi enviado"
  end
end
