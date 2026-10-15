require "test_helper"

class PlanPublisherTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @date = Date.new(2026, 10, 13)
  end

  teardown { ActsAsTenant.current_tenant = nil }

  test "enviar produção cria versão 1, depois 2, e congela os itens" do
    result = ProductionPlanner.new(company: company, date: @date).call
    first = PlanPublisher.production(company: company, result: result)
    second = PlanPublisher.production(company: company, result: result)
    assert_equal [ 1, 2 ], [ first.version, second.version ]
    assert_equal result.items.size, first.items.count
    assert first.sent?
    assert_empty PlanDiff.production(second, result)
  end

  test "alteração de pedido depois do envio aparece como diferença" do
    result = ProductionPlanner.new(company: company, date: @date).call
    plan = PlanPublisher.production(company: company, result: result)

    line = OrderLine.joins(:product).find_by!(products: { code: "cenoura_ralada" }, delivery_date: @date)
    line.update!(quantity: line.quantity + 4)
    changes = PlanDiff.production(plan, ProductionPlanner.new(company: company, date: @date).call)

    assert_equal 1, changes.size
    assert_equal "Cenoura ralada", changes.first.label
    assert_equal [ 3, 7 ], [ changes.first.before, changes.first.after ]
    assert_equal :changed, changes.first.kind
  end

  test "pedido novo vira item adicionado e linha apagada vira removido" do
    result = ProductionPlanner.new(company: company, date: @date).call
    plan = PlanPublisher.production(company: company, result: result)
    OrderLine.joins(:product).find_by!(products: { code: "couve_picada" }, delivery_date: @date).destroy!
    changes = PlanDiff.production(plan, ProductionPlanner.new(company: company, date: @date).call)
    assert_equal [ :removed ], changes.map(&:kind)
  end

  test "enviar compra guarda quantidade líquida, unidade e abertura por cliente" do
    needs = PurchasePlanner.new(company: company).call.purchases.fetch(@date)
    plan = PlanPublisher.purchase(company: company, date: @date, needs: needs)
    assert_equal needs.size, plan.items.count
    cenoura = plan.items.joins(:raw_material).find_by!(raw_materials: { code: "cenoura" }, unit: "kg")
    assert_predicate cenoura.breakdown, :present?
    assert_empty PlanDiff.purchase(plan, needs)
  end
end
