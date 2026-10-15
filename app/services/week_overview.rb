# Faixa da semana: em que dia cada setor produz (contagem de itens) e quais dias cada compra da CEASA cobre.
# Mesmas regras do ProductionPlanner e do PurchasePlanner, calculadas numa só consulta.
class WeekOverview
  Cell = Data.define(:date, :count, :first, :last)
  Lane = Data.define(:label, :kind, :cells) # kind: :production | :purchase
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
    sector_names = {}
    lines = OrderLine.where("quantity > 0").where(delivery_date: @start..(@start + DAYS + 2))
                     .includes(product: [ :cut, :production_rule ])
    lines.each do |line|
      product = line.product
      next if product.raw?

      production_date = product.production_date_for(line.delivery_date)
      next unless dates.include?(production_date)

      sector_names[product.sector] = product.cut.sector_name
      counts[[ product.sector, production_date ]] << [ product.id, line.unit ]
    end
    Cut::SECTORS.filter_map do |sector|
      next unless sector_names.key?(sector)

      cells = dates.map { |date| Cell.new(date: date, count: counts[[ sector, date ]].size, first: false, last: false) }
      Lane.new(label: sector_names[sector], kind: :production, cells: cells)
    end
  end

  def purchase_lane(dates)
    purchase_dates = PurchaseDay.where(date: (@start - 7)..(@start + DAYS + 7)).order(:date).pluck(:date)
    return nil if purchase_dates.empty?

    cells = dates.map do |date|
      covering = purchase_dates.select { |purchase_date| purchase_date <= date }.max
      next Cell.new(date: date, count: 0, first: false, last: false) unless covering

      following = purchase_dates.find { |purchase_date| purchase_date > date }
      Cell.new(date: date, count: 1, first: covering == date, last: following.nil? ? date == dates.last : following == date + 1)
    end
    Lane.new(label: "Compra CEASA", kind: :purchase, cells: cells)
  end
end
