require "test_helper"

class ProductionPlannerTest < ActiveSupport::TestCase
  test "domingo não tem produção: entrega na segunda produzida de véspera cai para sábado" do
    # 12/10/2026 é segunda; 11/10 é domingo e 10/10 é sábado.
    friday_plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 10)).call
    sunday_plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 11)).call
    assert_empty sunday_plan.items
    assert_includes friday_plan.delivery_dates, Date.new(2026, 10, 12)
  end

  test "ralados são produzidos no dia da entrega e cubinhos na véspera" do
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    assert_equal 3, plan.item_for("cenoura_ralada").quantity
    assert_equal [ Date.new(2026, 10, 13) ], plan.item_for("cenoura_ralada").breakdown.map(&:delivery_date).uniq
    assert_equal [ Date.new(2026, 10, 14) ], plan.item_for("baroa_cubinhos").breakdown.map(&:delivery_date).uniq
  end

  test "lista de um setor só tem os itens dele; a dos aprontes, só as caixas" do
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    assert_equal Cut::SECTORS.select { |s| plan.items.any? { |i| i.product.sector == s } } + [ "aprontes" ], plan.sectors

    ralpic = plan.for_sector("ralpic")
    assert ralpic.items.any?
    assert ralpic.items.all? { |item| item.product.sector == "ralpic" }
    assert_empty ralpic.aprontes
    assert_equal [ Date.new(2026, 10, 13) ], ralpic.delivery_dates

    aprontes = plan.for_sector("aprontes")
    assert_empty aprontes.items
    assert_equal plan.aprontes, aprontes.aprontes
    assert_same plan, plan.for_sector(nil)
  end

  test "aprontes: caixas = ROUND(kg processado / kg por caixa descascada)" do
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    batata = plan.aprontes.find { |a| a.raw_material.code == "batata" }
    assert_equal 36, batata.kg
    assert_equal (36 / 30.0).round, batata.boxes
  end

  test "in natura não entra na produção; as linhas in natura do dia somam a entrega do dia e a da antecedência" do
    ActsAsTenant.with_tenant(company) do
      order = Order.create!(customer: Customer.first, week_start: Date.new(2026, 11, 2))
      raw = Product.find_by!(product_group: "raw")
      [ 3, 4, 5 ].each { |day| order.lines.create!(product: raw, delivery_date: Date.new(2026, 11, day), quantity: 10, unit: "kg") }
    end

    planner = ProductionPlanner.new(company: company, date: Date.new(2026, 11, 3))
    assert_empty planner.call.items
    # 03/11 é entregue no dia; 04/11 conta para 03/11 pela antecedência de 1 dia; 05/11 é de outro dia.
    assert_equal [ Date.new(2026, 11, 3), Date.new(2026, 11, 4) ], planner.raw_lines.map(&:delivery_date).sort
  end

  test "breakdown guarda cliente e data de entrega" do
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    assert_equal 4, plan.item_for("batata_cubos").quantity
    assert_equal %w[hbp], plan.item_for("batata_cubos").breakdown.map { |b| b.customer.code }
  end

  test "os planejadores carregam clientes e matérias-primas de uma vez, sem uma consulta por linha" do
    date = Date.new(2026, 10, 13)
    count_queries = lambda do |&block|
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { ActiveRecord::Base.uncached(&block) }
      queries
    end

    assert_operator count_queries.call { PurchasePlanner.new(company: company).call }, :<=, 11
    assert_operator count_queries.call { ProductionPlanner.new(company: company, date: date).call }, :<=, 10
    assert_operator count_queries.call { ScheduleBuilder.new(company: company, date: date).call }, :<=, 8
  end
end
