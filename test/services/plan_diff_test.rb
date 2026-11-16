require "test_helper"

class PlanDiffTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @date = Date.new(2026, 10, 13)
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def publish = PlanPublisher.production(company: company, result: current)

  def current = ProductionPlanner.new(company: company, date: @date).call

  def lines_of(code) = OrderLine.joins(:product).where(products: { code: code }, delivery_date: @date)

  test "item que saiu do pedido depois do envio aparece como removido, com o setor da versão enviada" do
    plan = publish
    lines_of("cenoura_ralada").delete_all

    change = PlanDiff.production(plan, current).find { |c| c.label == "Cenoura ralada" }
    assert_equal :removed, change.kind
    assert_nil change.after
    assert_equal "ralpic", change.sector
  end

  test "versão enviada igual ao cálculo atual não tem diferença" do
    assert_empty PlanDiff.production(publish, current)
  end

  test "medida nova pedida depois do envio aparece como item novo, com a medida no nome (D24)" do
    plan = publish
    updated = OrderLine.joins(:product, order: :customer).where(products: { code: "batata_cubinhos" }, customers: { code: "hnorte" },
                                                                delivery_date: @date + 1).update_all(measure: "12 × 12 mm")
    assert_equal 1, updated
    changes = PlanDiff.production(plan, current).to_h { |c| [ c.label, [ c.before, c.after ] ] }
    assert_equal [ 32, 25 ], changes["Batata em cubinhos"]
    assert_equal [ nil, 7 ], changes["Batata em cubinhos · 12 × 12 mm"]
  end

  test "versão enviada antes da D24 (sem medida) não aparece como mudada" do
    plan = publish
    plan.items.update_all(measure: nil)
    assert_empty PlanDiff.production(ProductionPlan.find(plan.id), current)
  end

  test "a versão enviada guarda a medida de cada item" do
    plan = publish
    assert_equal "10 × 10 × 10 mm", plan.items.joins(:product).find_by!(products: { code: "batata_cubinhos" }).measure
    assert_equal current.items.map(&:label), ProductionPlan.find(plan.id).to_result.items.map(&:label)
  end

  test "o nome da mudança é o da linha atual, para a tela marcar \"mudou\" na linha certa (D24)" do
    rows = OrderLine.joins(:product, order: :customer).where(products: { code: "batata_cubinhos" }, delivery_date: @date + 1)
    rows.update_all(measure: "12x12")
    plan = publish
    assert_equal [ "Batata em cubinhos · 12x12" ], ProductionPlan.find(plan.id).to_result.items.map(&:label).grep(/Batata em cubinhos/)
    rows.update_all(measure: "12 × 12 mm")
    rows.where(customers: { code: "hbp" }).update_all(quantity: 26)
    labels = current.items.map(&:label)
    changes = PlanDiff.production(ProductionPlan.find(plan.id), current)
    assert_equal [ [ "Batata em cubinhos · 12 × 12 mm", 32, 33 ] ], changes.map { |c| [ c.label, c.before, c.after ] }
    assert_includes labels, changes.first.label
  end
end
