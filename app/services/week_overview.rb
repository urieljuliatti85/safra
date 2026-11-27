# Faixa da semana: quantos itens a Planilha de Produção tem em cada dia de execução e quais dias cada compra da CEASA
# cobre. Sem setores no MVP (esteira simplificada).
# Mesmas regras do ProductionPlanner e do PurchasePlanner, calculadas numa só consulta.
class WeekOverview
  Cell = Data.define(:date, :count, :first, :last)
  Lane = Data.define(:label, :kind, :cells, :sector) # kind: :production | :purchase; sector: código do setor na produção
  Result = Data.define(:dates, :lanes)

  DAYS = 8 # segunda a segunda, como a grade de pedidos

  def initialize(company:, date:)
    @company = company
    @start = date.beginning_of_week
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      dates = (@start...(@start + DAYS)).to_a
      Result.new(dates: dates, lanes: production_lanes(dates) + [ purchase_lane(dates) ].compact)
    end
  end

  private

  def production_lanes(dates)
    counts = Hash.new { |hash, key| hash[key] = Set.new }
    lines = OrderLine.where("quantity > 0").where(delivery_date: @start..(@start + DAYS + 2))
                     .includes({ order: :customer }, product: [ :cut, :production_rule, { components: { component: :cut } } ])
    lines.each do |line|
      next if line.product.raw?

      production_date = line.execution_on
      next unless dates.include?(production_date)

      # Um item por produto, medida e unidade, com a mistura aberta nos ingredientes, como na produção (D24, D25).
      ProductionPlanner.portions(line).each do |portion|
        product = portion.product
        counts[production_date] << [ product.id, Cut.measure_key(ProductionPlanner.measure_of(portion)), portion.unit ]
      end
    end
    return [] if counts.empty?

    cells = dates.map { |date| Cell.new(date: date, count: counts[date].size, first: false, last: false) }
    [ Lane.new(label: "Planilha de Produção", kind: :production, cells: cells, sector: nil) ]
  end

  def purchase_lane(dates)
    purchase_dates = PurchaseCalendar.new(@company).between((@start - 7)..(@start + DAYS + 7))
    return nil if purchase_dates.empty?

    cells = dates.map do |date|
      covering = purchase_dates.select { |purchase_date| purchase_date <= date }.max
      next Cell.new(date: date, count: 0, first: false, last: false) unless covering

      following = purchase_dates.find { |purchase_date| purchase_date > date }
      Cell.new(date: date, count: 1, first: covering == date, last: following.nil? ? date == dates.last : following == date + 1)
    end
    Lane.new(label: "Compra CEASA", kind: :purchase, cells: cells, sector: nil)
  end
end
