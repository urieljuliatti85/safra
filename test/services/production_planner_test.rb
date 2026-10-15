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

  test "aprontes: caixas = ROUND(kg processado / kg por caixa descascada)" do
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    batata = plan.aprontes.find { |a| a.raw_material.code == "batata" }
    assert_equal 36, batata.kg
    assert_equal (36 / 30.0).round, batata.boxes
  end

  test "breakdown guarda cliente e data de entrega" do
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    assert_equal 4, plan.item_for("batata_cubos").quantity
    assert_equal %w[hbp], plan.item_for("batata_cubos").breakdown.map { |b| b.customer.code }
  end
end
