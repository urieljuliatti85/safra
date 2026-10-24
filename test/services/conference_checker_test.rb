require "test_helper"

class ConferenceCheckerTest < ActiveSupport::TestCase
  test "alerta, sem erro, sobre fator ausente, unidades e observações do pedido" do
    alerts = ConferenceChecker.new(company: company).call
    messages = alerts.map(&:message)
    assert(messages.any? { |m| m.include?("Cebola") && m.include?("sem fator") })
    assert(messages.any? { |m| m.include?("Pedido diz 1 un; a programação usa 100") })
    assert_equal 1, messages.count { |m| m.include?("Horiz. Sul: Batata em cubinhos") }
    assert(alerts.any? { |a| a.kind == "Unidade" })
    assert alerts.first.level == :warn
  end

  test "a semana filtra pela data de entrega: a segunda 19/10 do pedido de 12/10 cai na semana seguinte" do
    jilo = ->(week) { ConferenceChecker.new(company: company, week: week).call.any? { |a| a.kind == "Sem fator" && a.message.start_with?("Jiló:") } }
    assert jilo.call(nil)
    assert_not jilo.call(Date.new(2026, 10, 12))
    assert jilo.call(Date.new(2026, 10, 19))
    assert_empty ConferenceChecker.new(company: company, week: Date.new(2026, 10, 26)).call
    assert_empty ConferenceChecker.new(company: company, week: Date.new(2026, 10, 5)).call
  end

  test "alerta de cadastro só aparece se a matéria-prima tem entrega na semana" do
    ActsAsTenant.with_tenant(company) do
      first_monday = Date.new(2026, 10, 12)
      OrderLine.where(delivery_date: first_monday..(first_monday + 6)).joins(product: :raw_material).where(raw_materials: { code: "cebola" }).update_all(delivery_date: Date.new(2026, 10, 26))
    end
    assert(ConferenceChecker.new(company: company).call.any? { |a| a.kind == "Sem fator" && a.message.start_with?("Cebola:") })
    assert_not ConferenceChecker.new(company: company, week: Date.new(2026, 10, 12)).call.any? { |a| a.kind == "Sem fator" && a.message.start_with?("Cebola:") }
    assert(ConferenceChecker.new(company: company, week: Date.new(2026, 10, 26)).call.any? { |a| a.kind == "Sem fator" && a.message.start_with?("Cebola:") })
  end

  test "a ordem dos alertas é estável: gravidade, tipo e texto" do
    alerts = ConferenceChecker.new(company: company).call
    assert_equal alerts.sort_by { |a| [ a.level == :warn ? 0 : 1, a.kind, a.message ] }, alerts
    assert_equal alerts.map(&:message), ConferenceChecker.new(company: company).call.map(&:message)
  end

  test "cada alerta com um lugar certo para corrigir leva até ele" do
    alerts = ConferenceChecker.new(company: company).call
    sem_fator = alerts.find { |a| a.kind == "Sem fator" && a.message.start_with?("Cebola") }
    assert_equal "Completar o fator", sem_fator.action.label
    assert_equal "/cadastros/materias-primas?q=Cebola", sem_fator.action.path

    unidade = alerts.find { |a| a.kind == "Unidade" }
    assert_match %r{\A/orders\?customer=\w+&week=\d{4}-\d{2}-\d{2}\z}, unidade.action.path
    assert_match(/\AAbrir pedido de /, unidade.action.label)

    pedido = alerts.find { |a| a.kind == "Pedido" }
    assert_match %r{\A/orders\?customer=}, pedido.action.path
  end

  test "ação de pedido abre a semana da linha mais antiga do problema" do
    ActsAsTenant.with_tenant(company) do
      line = OrderLine.where("quantity > 0").joins(:order).order(:delivery_date).first
      line.update!(note: "entregar até 7h")
      alert = ConferenceChecker.new(company: company).call.find { |a| a.kind == "Pedido" && a.message.include?("entregar até 7h") }
      assert_includes alert.action.path, "customer=#{line.order.customer.code}"
      assert_includes alert.action.path, "week=#{line.order.week_start.iso8601}"
    end
  end

  test "fornecedor aponta para o filtro do cadastro" do
    ActsAsTenant.with_tenant(company) { Product.joins(:order_lines).distinct.first.raw_material.update_columns(supplier_id: nil) }
    alert = ConferenceChecker.new(company: company).call.find { |a| a.kind == "Fornecedor" }
    assert_equal "/cadastros/materias-primas?filter=no_supplier", alert.action.path
  end

  test "produção antes da primeira compra aponta para os dias de compra nas regras" do
    ActsAsTenant.with_tenant(company) { PurchaseDay.where(date: ..Date.new(2026, 10, 13)).destroy_all }
    alert = ConferenceChecker.new(company: company).call.find { |a| a.kind == "Compra" }
    assert_equal "Cadastrar dia de compra", alert.action.label
    assert_equal "/regras#compras", alert.action.path
  end

  test "usa a compra já calculada por quem chama, sem refazer" do
    ActsAsTenant.with_tenant(company) { PurchaseDay.where(date: ..Date.new(2026, 10, 13)).destroy_all }
    calculated = PurchasePlanner::Result.new(purchases: {}, uncovered: [])
    alerts = ConferenceChecker.new(company: company, purchase_result: calculated).call
    assert_nil alerts.find { |a| a.kind == "Compra" }
  end

  test "com a compra do Painel, os alertas são os mesmos de calcular sozinho, em cada semana" do
    result = ActsAsTenant.with_tenant(company) { PurchasePlanner.new(company: company).call }
    assert result.uncovered.any?, "os seeds precisam ter linhas sem compra para o caso valer"
    [ nil, Date.new(2026, 10, 12), Date.new(2026, 10, 19) ].each do |week|
      alone = ConferenceChecker.new(company: company, week: week).call
      shared = ConferenceChecker.new(company: company, week: week, purchase_result: result).call
      assert_equal alone, shared, "semana #{week.inspect}"
    end
  end

  test "linhas sem compra recebidas de fora continuam filtradas pela semana" do
    lines = ActsAsTenant.with_tenant(company) { OrderLine.where("quantity > 0").order(:delivery_date).to_a }
    week = Date.new(2026, 10, 12)
    in_week = lines.select { |l| (week..week + 6).cover?(l.delivery_date) }.first(2)
    other_week = lines.reject { |l| (week..week + 6).cover?(l.delivery_date) }.first(3)
    assert_equal 2, in_week.size
    assert other_week.any?

    result = PurchasePlanner::Result.new(purchases: {}, uncovered: in_week + other_week)
    alert = ConferenceChecker.new(company: company, week: week, purchase_result: result).call.find { |a| a.kind == "Compra" }
    assert_match(/\A2 linhas de pedido/, alert.message)

    only_other = PurchasePlanner::Result.new(purchases: {}, uncovered: other_week)
    assert_nil ConferenceChecker.new(company: company, week: week, purchase_result: only_other).call.find { |a| a.kind == "Compra" }
  end

  test "entrega no domingo abre o pedido da semana dela" do
    ActsAsTenant.with_tenant(company) do
      line = OrderLine.where("quantity > 0").joins(:order).order(:delivery_date).first
      line.update!(delivery_date: Date.new(2026, 10, 18))
      alert = ConferenceChecker.new(company: company).call.find { |a| a.kind == "Data" }
      assert_includes alert.action.path, "customer=#{line.order.customer.code}"
    end
  end

  def quantity_alerts(week: nil) = ConferenceChecker.new(company: company, week: week).call.select { |a| a.kind == "Quantidade" }

  def customer_lines(code, product_name)
    OrderLine.joins(:product, order: :customer).where(customers: { code: code }, products: { name: product_name })
  end

  test "quantidade bem acima do normal do cliente avisa e abre o pedido" do
    alerts = quantity_alerts
    assert_equal [ "Horiz. Norte: Batata em cubos com 80 kg em 15/10, quando o normal é 16 kg. Confira se não é erro de digitação.",
                   "Bom Pastor: Cenoura em palitos com 76 kg em 13/10, quando o normal é 2 kg. Confira se não é erro de digitação." ], alerts.map(&:message)
    assert alerts.all? { |a| a.level == :warn }
    assert_includes alerts.first.action.path, "customer=hnorte"
  end

  test "zero a mais vira aviso; zero a menos e números pequenos não" do
    ActsAsTenant.with_tenant(company) do
      batata = customer_lines("hnorte", "Batata em cubos")
      batata.find_by(delivery_date: "2026-10-15").update!(quantity: 15)
      assert_no_match "Batata em cubos", quantity_alerts.map(&:message).join

      batata.find_by(delivery_date: "2026-10-16").update!(quantity: 160)
      assert_match "Batata em cubos com 160 kg em 16/10", quantity_alerts.map(&:message).join

      batata.find_by(delivery_date: "2026-10-16").update!(quantity: 1.6)
      assert_no_match "Batata em cubos", quantity_alerts.map(&:message).join, "pedido pequeno costuma ser de propósito"
    end
    # Couve picada do Horiz. Norte: 1, 8, 1 e 2 kg. 8 passa de 5 vezes o normal, mas só 7 kg acima: não avisa.
    assert_no_match "Couve picada", quantity_alerts.map(&:message).join
  end

  test "quantidade alta que já se repetiu é padrão do cliente, não erro" do
    # Inhame em cubos da Bom Pastor: 52 kg na segunda e no domingo, 7 a 10 kg nos outros dias.
    assert_no_match "Inhame", quantity_alerts.map(&:message).join
    ActsAsTenant.with_tenant(company) { customer_lines("hbp", "Inhame em cubos").find_by(delivery_date: "2026-10-18").update!(quantity: 9) }
    assert_match "Inhame em cubos com 52 kg em 12/10", quantity_alerts.map(&:message).join
  end

  test "sem histórico suficiente não há o que comparar" do
    ActsAsTenant.with_tenant(company) do
      customer_lines("hnorte", "Batata em cubos").where.not(delivery_date: [ "2026-10-15", "2026-10-16", "2026-10-17" ]).delete_all
    end
    assert_no_match "Batata em cubos", quantity_alerts.map(&:message).join
  end

  test "a semana filtra o aviso" do
    assert_empty quantity_alerts(week: Date.new(2026, 10, 19))
    assert_equal 2, quantity_alerts(week: Date.new(2026, 10, 12)).size
  end
end
