require "test_helper"

# Faixa da semana: uma linha da Planilha de Produção (sem setores, esteira simplificada) com o mesmo número de itens
# que a Planilha de cada dia de execução.
class WeekOverviewTest < ActiveSupport::TestCase
  def count_on(date)
    lane = WeekOverview.new(company: company, date: date).call.lanes.find { |l| l.kind == :production }
    lane.cells.find { |c| c.date == date }.count
  end

  test "conta um item por produto, medida e unidade, como a Planilha de Produção (D24)" do
    date = Date.new(2026, 10, 13)
    production = -> { ProductionPlanner.new(company: company, date: date).call.items.size }
    assert_equal production.call, count_on(date)
    ActsAsTenant.with_tenant(company) do
      OrderLine.joins(:product, order: :customer).where(products: { code: "batata_cubinhos" }, customers: { code: "hnorte" }, delivery_date: date + 1)
               .update_all(measure: "12 × 12 mm")
    end
    assert_equal production.call, count_on(date)
  end

  test "abre a mistura nos ingredientes e segue o dia de execução escolhido, como a Planilha de Produção (D25)" do
    date = Date.new(2026, 10, 13)
    assert_equal ProductionPlanner.new(company: company, date: date).call.items.size, count_on(date)
    ActsAsTenant.with_tenant(company) do
      OrderLine.joins(:product).where(products: { code: "baroa_cubinhos" }, delivery_date: date + 1).update_all(execution_date: date - 1)
    end
    assert_equal ProductionPlanner.new(company: company, date: date - 1).call.items.size, count_on(date - 1)
    assert_equal ProductionPlanner.new(company: company, date: date).call.items.size, count_on(date)
  end

  test "sem setores: uma linha só para a produção" do
    lanes = WeekOverview.new(company: company, date: Date.new(2026, 10, 13)).call.lanes
    assert_equal [ "Planilha de Produção" ], lanes.select { |l| l.kind == :production }.map(&:label)
  end
end
