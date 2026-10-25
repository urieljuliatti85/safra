require "test_helper"

# Dois envios do mesmo dia ao mesmo tempo, cada um na sua conexão: precisa de commit de verdade para os dois
# disputarem a mesma versão, então este teste roda fora da transação e apaga o que criou.
class PlanPublisherConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  DATE = Date.new(2026, 10, 13)

  teardown do
    ActsAsTenant.with_tenant(company) do
      ProductionPlan.where(date: DATE).find_each { |plan| plan.items.delete_all && plan.delete }
      PurchasePlan.where(date: DATE).find_each { |plan| plan.items.delete_all && plan.delete }
    end
  end

  def race(&publish)
    gate = Queue.new
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          publish.call.version
        end
      end
    end
    2.times { gate << true }
    threads.map(&:value).sort
  end

  test "envio de produção simultâneo vira versões 1 e 2, sem erro" do
    result = ActsAsTenant.with_tenant(company) { ProductionPlanner.new(company: company, date: DATE).call }

    assert_equal [ 1, 2 ], race { PlanPublisher.production(company: company, result: result) }
  end

  test "envio de compra simultâneo vira versões 1 e 2, sem erro" do
    needs = ActsAsTenant.with_tenant(company) { PurchasePlanner.new(company: company).call.purchases.fetch(DATE) }

    assert_equal [ 1, 2 ], race { PlanPublisher.purchase(company: company, date: DATE, needs: needs) }
  end
end
