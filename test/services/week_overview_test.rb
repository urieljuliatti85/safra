require "test_helper"

class WeekOverviewTest < ActiveSupport::TestCase
  test "conta um item por produto, medida e unidade, como a produção (D24)" do
    date = Date.new(2026, 10, 13)
    count = lambda do
      lane = WeekOverview.new(company: company, date: date).call.lanes.find { |l| l.sector == "cubinho" }
      lane.cells.find { |c| c.date == date }.count
    end
    production = -> { ProductionPlanner.new(company: company, date: date).call.items.count { |i| i.product.sector == "cubinho" } }
    assert_equal production.call, count.call
    ActsAsTenant.with_tenant(company) do
      OrderLine.joins(:product, order: :customer).where(products: { code: "batata_cubinhos" }, customers: { code: "hnorte" }, delivery_date: date + 1)
               .update_all(measure: "12 × 12 mm")
    end
    assert_equal production.call, count.call
    assert_equal 6, count.call
  end
end
