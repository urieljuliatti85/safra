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
    travel_to Time.zone.local(2026, 10, 5, 9) # antes das 48 h da entrega (R1.26)
    visit orders_path(customer: "hnorte", week: "2026-10-12")
    assert_selector "h1", text: "Hospital Horizonte Norte"

    fill_in "Cenoura ralada em Ter 13/10", with: "9,5"
    choose "Alteração (novo total)"
    click_on "Salvar pedido"

    assert_text "Pedido salvo: versão 2, 1 alteração."
    assert_field "Cenoura ralada em Ter 13/10", with: "9,5"
  end

  test "adicionar vários produtos sem recarregar e salvar uma vez só, numa versão só" do
    travel_to Time.zone.local(2026, 10, 26, 9) # antes das 48 h da entrega (R1.26)
    visit orders_path(customer: "hnorte", week: "2026-11-02")
    assert_text "Nenhum produto nesta semana"

    select "Acelga picada (kg)", from: "Adicionar produto"
    click_on "Adicionar linha"
    assert_selector "tr.is-new-line", text: "Acelga picada"
    assert_no_text "Nenhum produto nesta semana"
    fill_in "Acelga picada em Seg 02/11", with: "4"

    select "Cenoura ralada (kg)", from: "Adicionar produto"
    click_on "Adicionar linha"
    assert_field "Acelga picada em Seg 02/11", with: "4" # o que já foi digitado fica
    fill_in "Cenoura ralada em Ter 03/11", with: "2,5"
    assert_selector "#add option[disabled]", text: "Acelga picada (kg)"

    select "Abóbora em cubos (kg)", from: "Adicionar produto"
    click_on "Adicionar linha"
    click_on "Remover Abóbora em cubos"
    assert_no_field "Abóbora em cubos em Seg 02/11"
    assert_selector "#add option:not([disabled])", text: "Abóbora em cubos (kg)"

    choose "Pedido novo"
    click_on "Salvar pedido"
    assert_text "Pedido salvo: versão 1"
    assert_field "Acelga picada em Seg 02/11", with: "4"
    assert_field "Cenoura ralada em Ter 03/11", with: "2,5"

    ActsAsTenant.with_tenant(company) do
      order = Order.joins(:customer).find_by!(customers: { code: "hnorte" }, week_start: Date.new(2026, 11, 2))
      assert_equal 1, order.versions.count
      assert_equal 2, order.lines.count
    end
  end

  test "texto inválido na grade não salva e aponta a célula" do
    visit orders_path(customer: "hnorte", week: "2026-10-12")

    fill_in "Cenoura ralada em Ter 13/10", with: "5 + 2"
    choose "Alteração (novo total)"
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
