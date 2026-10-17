require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  def publish_production(date)
    ActsAsTenant.with_tenant(company) do
      PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: date).call)
    end
  end

  test "escritório cai no painel com as quatro etapas na ordem do trabalho" do
    sign_in_as(user_for(:office))
    get root_path
    assert_redirected_to dashboard_path
    travel_to(Time.zone.local(2026, 10, 13, 9)) { follow_redirect! }
    assert_select "h1", "Painel"
    assert_select ".flow-step h2", count: 4
    assert_equal %w[Pedidos Programação Produção Compras], css_select(".flow-step h2").map(&:text)
    assert_select "nav a[aria-current=page]", text: "Painel"
    assert_select ".week", count: 0
    assert_select ".flow-step[data-state=ok] a.btn", count: 0
    link = css_select(".flow-step:first-child a").find { |a| a.text.match?(/alertas? para conferir/) }
    assert_equal "/conference?week=2026-10-12", link["href"]
    assert_select ".flash-notice", count: 0
  end

  test "etapa de pedidos destaca os alertas de atenção da semana e diz o que pesa neles" do
    sign_in_as(user_for(:office))
    travel_to(Time.zone.local(2026, 10, 13, 9)) { get dashboard_path }
    link = css_select(".flow-step:first-child a.flow-link-attention").first
    assert_match(/\A\s*\d+ alertas para conferir\s*\z/, link.text)
    assert_select ".flow-step:first-child a.flow-link-attention svg"
    facts = css_select(".flow-step:first-child .flow-facts li").map(&:text)
    breakdown = facts.find { |fact| fact.start_with?("Alertas:") }
    assert_match(/matérias-primas sem fator/, breakdown)
    assert_match(/matérias-primas com unidades misturadas/, breakdown)
    assert_match(/observações em pedidos/, breakdown)
    assert breakdown.index("sem fator") < breakdown.index("unidades misturadas"), "o mais grave vem primeiro"
  end

  test "semana sem alerta de atenção não mostra o link nem o resumo" do
    sign_in_as(user_for(:office))
    travel_to(Time.zone.local(2026, 10, 27, 9)) { get dashboard_path }
    assert_select ".flow-step:first-child a.flow-link-attention", count: 0
    assert_select ".flow-step:first-child .flow-facts li", text: /\AAlertas:/, count: 0
  end

  test "produção continua caindo na própria tela e não abre o painel" do
    sign_in_as(user_for(:production))
    get root_path
    assert_redirected_to production_path
    get dashboard_path
    assert_redirected_to production_path
    follow_redirect!
    assert_select "nav a", text: "Painel", count: 0
  end

  test "produção sem envio fica pendente com a ação de revisar e enviar" do
    travel_to Time.zone.local(2026, 10, 13, 9) do
      sign_in_as(user_for(:office))
      get dashboard_path
      assert_select ".flow-step[data-state=pending] .flow-status", /Falta enviar aos setores/
      assert_select ".flow-step[data-state=pending] a.btn-primary", text: "Revisar e enviar"
    end
  end

  test "produção enviada aparece em ordem e mudança depois do envio vira aviso" do
    travel_to Time.zone.local(2026, 10, 13, 9) do
      publish_production(Date.new(2026, 10, 13))
      sign_in_as(user_for(:office))
      get dashboard_path
      assert_select ".flow-step[data-state=ok] .flow-status", /Enviada, versão 1/
      assert_select ".flash-alert", count: 0

      product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "cenoura_ralada") }
      patch orders_path(customer: "hnorte", week: "2026-10-12"), params: { quantities: { "#{product.id}|kg" => { "2026-10-13" => "99" } } }
      get dashboard_path
      assert_select ".flow-step[data-state=changed] .flow-status", /1 item mudou depois do envio/
      assert_select ".flow-step[data-state=changed] a.btn-primary", text: "Ver diferença e reenviar"
      assert_select ".flash-alert", /Mudou depois do envio:.*produção de 13\/10/
    end
  end

  test "compra mostra o próximo dia da CEASA e leva ao estoque quando falta contar" do
    travel_to Time.zone.local(2026, 10, 13, 9) do
      sign_in_as(user_for(:office))
      get dashboard_path
      assert_select ".flow-step h2", text: "Compras"
      assert_select ".flow-facts li", /Próxima compra: /
      assert_select ".flow-step a", text: "Contar estoque"
    end
  end

  test "pedidos dizem quais clientes faltam lançar" do
    ActsAsTenant.with_tenant(company) { Customer.create!(code: "novo", name: "Cliente Novo", short_name: "Novo") }
    sign_in_as(user_for(:office))
    get dashboard_path
    assert_select ".flow-step[data-state=pending] .flow-status", /Falta 1 cliente na semana/
    assert_select ".flow-facts li", /Falta: Novo/
  end
end
