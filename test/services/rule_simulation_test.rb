require "test_helper"

class RuleSimulationTest < ActiveSupport::TestCase
  setup { ActsAsTenant.current_tenant = company }
  teardown { ActsAsTenant.current_tenant = nil }

  test "simular cubinhos no dia da entrega melhora o placar e não grava nada" do
    cut = Cut.find_by!(code: "cubinhos")
    result = RuleSimulation.new(company: company, changes: RuleChanges.new(cut_leads: { cut.id => 0 })).call

    assert_empty result.errors
    assert_equal 13, result.before_score[:production][0]
    assert_equal 19, result.after_score[:production][0]
    assert_equal 7, result.improved # itens que passam a bater
    assert_equal 1, result.worsened # um item que batia deixa de bater: o placar líquido é +6
    assert_equal 1, cut.reload.lead_days
  end

  test "a empresa em memória volta ao valor salvo depois de simular a antecedência do in natura" do
    RuleSimulation.new(company: company, changes: RuleChanges.new(raw_lead_days: 3)).call
    assert_equal 1, company.raw_lead_days
    assert_equal 1, Company.find(company.id).raw_lead_days
  end

  test "mudança inválida devolve o erro e não deixa nada" do
    cut = Cut.find_by!(code: "cubos")
    result = RuleSimulation.new(company: company, changes: RuleChanges.new(cut_leads: { cut.id => 9 })).call
    assert_match "Lead days", result.errors.first
    assert_nil result.after_score
    assert_equal 1, cut.reload.lead_days
  end

  test "sem mudança nada muda de valor" do
    result = RuleSimulation.new(company: company, changes: RuleChanges.new).call
    assert_empty result.deltas
    assert_equal result.before_score, result.after_score
  end
end
