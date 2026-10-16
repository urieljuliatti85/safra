require "test_helper"

class IndicatorsTest < ActionDispatch::IntegrationTest
  test "escritório vê volume, perdas, compras e ranking da semana" do
    sign_in_as(user_for(:office))
    get indicators_path(week: "2026-10-12")
    assert_response :success
    assert_select "h1", "BI"
    assert_select "nav a[aria-current=page]", text: "BI"
    assert_select ".bi-facts dt", count: 3
    assert_select ".bi-cols li", count: 7
    assert_select "#bi-days"
    assert_select "section[aria-labelledby=bi-loss] .bi-rows li", minimum: 1
    assert_select "#bi-buy"
    assert_select "#bi-customers"
    assert_select "#bi-products"
  end

  test "setas levam à semana anterior e à seguinte e semana sem pedidos mostra o caminho para lançar" do
    sign_in_as(user_for(:office))
    get indicators_path(week: "2026-10-12")
    assert_select "a[aria-label='Semana anterior'][href=?]", indicators_path(week: "2026-10-05")
    assert_select "a[aria-label='Próxima semana'][href=?]", indicators_path(week: "2026-10-19")
    get indicators_path(week: "2026-01-05")
    assert_select ".bi-empty h2", "Sem pedidos nesta semana"
    assert_select "a", text: "Abrir pedidos"
  end

  test "data inválida volta para a semana atual" do
    sign_in_as(user_for(:office))
    get indicators_path(week: "ontem")
    assert_redirected_to indicators_path
  end

  test "produção não abre o BI nem vê o link" do
    sign_in_as(user_for(:production))
    get indicators_path
    assert_redirected_to production_path
    follow_redirect!
    assert_select "nav a", text: "BI", count: 0
  end

  test "totais da tela batem com a API de BI" do
    sign_in_as(user_for(:office))
    summary = IndicatorsSummary.new(company: company, date: Date.new(2026, 10, 12)).call
    rows = ActsAsTenant.with_tenant(company) { BiReport.new(company: company, from: Date.new(2026, 10, 12), to: Date.new(2026, 10, 18)).production }.select { |r| r[:unit] == "kg" }
    assert_in_delta rows.sum { |r| r[:quantity] }, summary.production_kg, 0.001
    assert_in_delta summary.days.sum(&:kg), summary.production_kg, 0.001
  end
end
