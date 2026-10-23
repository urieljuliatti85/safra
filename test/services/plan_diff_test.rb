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
end
