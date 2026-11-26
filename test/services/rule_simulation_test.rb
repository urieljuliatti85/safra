require "test_helper"

class RuleSimulationTest < ActiveSupport::TestCase
  setup { ActsAsTenant.current_tenant = company }
  teardown { ActsAsTenant.current_tenant = nil }

  test "simular cubinhos no dia da entrega melhora o placar e não grava nada" do
    cut = Cut.find_by!(code: "cubinhos")
    result = RuleSimulation.new(company: company, changes: RuleChanges.new(cut_leads: { cut.id => 0 })).call

    assert_empty result.errors
    # 11, e não 13: cenoura ralada e repolho picado somam a Yaksoba pelos ingredientes (R2.8, D25), e a planilha não.
    # Com D41 (arredondamento por produto), a mudança de cubinhos 1→0 melhora o placar de 11 para 17.
    # D41 também aumenta o worsened (eram 1, agora 2), pois a produção mudou para mais itens.
    assert_equal 11, result.before_score[:production][0]
    assert_equal 17, result.after_score[:production][0]
    assert_equal 7, result.improved # itens que passam a bater
    assert_equal 2, result.worsened # itens que deixam de bater (eram 1 sem D41)
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
    assert_match "Cubos: Antecedência deve estar em 0..5", result.errors.first
    assert_nil result.after_score
    assert_equal 1, cut.reload.lead_days
  end

  test "sem mudança nada muda de valor" do
    result = RuleSimulation.new(company: company, changes: RuleChanges.new).call
    assert_empty result.deltas
    assert_equal result.before_score, result.after_score
  end
end
