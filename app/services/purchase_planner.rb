# Calcula a necessidade de compra por dia de compra (CEASA) e matéria-prima.
# Cada compra abastece a produção do dia da compra até a véspera da compra seguinte.
# O estoque da câmara fria é abatido antes, na ordem das compras.
# Referência: função necessidade() do protótipo (docs/prototipo/safra.html, privado).
class PurchasePlanner
  Need = Data.define(
    :raw_material, :unit,
    :processed_quantity, # pedido em produtos processados (na unidade do pedido)
    :raw_quantity,       # pedido in natura (na unidade do pedido)
    :kg,                 # necessidade bruta em kg in natura
    :stock_kg,           # abatido da câmara fria
    :net_kg,             # necessidade líquida em kg
    :packages,           # caixas/sacos inteiros a comprar, somados por produto (R3.9); nil se não dá para calcular
    :loose_kg,           # kg além das caixas, dos produtos comprados em fração (R3.9: "2 caixas e 5 kg")
    :net_packages,       # kg líquido em caixas, antes do arredondamento (para a tela)
    :missing_factor,     # true quando faltou fator ou a unidade não é kg (quantidade somada sem converter)
    :breakdown
  )
  Breakdown = Data.define(:customer, :product, :delivery_date, :production_date, :quantity, :unit)
  Result = Data.define(:purchases, :uncovered) do
    # purchases: { Date => [Need] }; uncovered: linhas cuja produção cai antes da primeira compra.
    def need_for(date, raw_material_code, unit = nil)
      purchases.fetch(date, []).find do |need|
        need.raw_material.code == raw_material_code && (unit.nil? || need.unit == unit)
      end
    end
  end

  def initialize(company:)
    @company = company
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      purchase_dates = PurchaseDay.order(:date).pluck(:date)
      raw_needs, uncovered = accumulate(purchase_dates)
      Result.new(purchases: finalize(raw_needs, purchase_dates), uncovered: uncovered)
    end
  end

  private

  def accumulate(purchase_dates)
    needs = purchase_dates.index_with { {} }
    uncovered = []
    lines = OrderLine.where("quantity > 0").includes({ order: :customer }, product: [ :cut, :production_rule, { raw_material: :supplier } ])

    lines.each do |line|
      product = line.product
      production_date = product.production_date_for(line.delivery_date)
      purchase_date = purchase_dates.select { |date| date <= production_date }.max
      (uncovered << line) && next unless purchase_date

      need = (needs[purchase_date][[ product.raw_material, line.unit ]] ||= { processed: 0, raw: 0, kg: 0, missing_factor: false, breakdown: [] })
      add_quantity(need, product, line)
      need[:breakdown] << Breakdown.new(
        customer: line.order.customer, product: product, delivery_date: line.delivery_date,
        production_date: production_date, quantity: line.quantity, unit: line.unit
      )
    end
    [ needs, uncovered ]
  end

  def add_quantity(need, product, line)
    quantity = line.quantity
    factor = product.raw_material.multiply_factor
    if product.raw?
      need[:raw] += quantity
      need[:kg] += quantity
    elsif line.unit != "kg"
      need[:processed] += quantity
      need[:kg] += quantity
      need[:missing_factor] = true
    else
      need[:processed] += quantity
      need[:kg] += factor ? quantity * factor : quantity
      need[:missing_factor] = true unless factor
    end
  end

  # O estoque da câmara fria abate a compra: a contagem mais recente até o dia da compra vale para ela, e o que
  # sobra depois de abater vai para a compra seguinte, a não ser que uma contagem nova (feita depois da compra
  # anterior) o substitua. Só abate o que é pedido em kg.
  def finalize(raw_needs, purchase_dates)
    counts = StockCount.order(:date, :id).to_a
    stock = Hash.new(0)
    previous_date = nil
    purchase_dates.index_with do |date|
      apply_counts(stock, counts, previous_date, date)
      previous_date = date
      raw_needs[date].map do |(raw_material, unit), need|
        stock_kg = unit == "kg" ? [ stock[raw_material.id], need[:kg] ].min : 0
        stock[raw_material.id] -= stock_kg if stock_kg.positive?
        net_kg = [ need[:kg] - stock_kg, 0 ].max

        packages, loose_kg = packages_for(raw_material, unit, need, net_kg)

        Need.new(
          raw_material: raw_material, unit: unit,
          processed_quantity: need[:processed], raw_quantity: need[:raw],
          kg: need[:kg], stock_kg: stock_kg, net_kg: net_kg,
          packages: packages, loose_kg: loose_kg,
          net_packages: packages && (net_kg / raw_material.kg_per_package).round(2),
          missing_factor: need[:missing_factor],
          breakdown: need[:breakdown]
        )
      end.sort_by { |need| [ need.raw_material.supplier&.name.to_s, need.raw_material.name, need.unit ] }
    end
  end

  # Arredondamento por produto (R3.9, D41): o kg líquido da matéria-prima é repartido entre os produtos na proporção
  # do kg bruto de cada um. Produto de caixa inteira arredonda a sua parte para cima; produto em fração entra com o kg
  # exato. Soma tudo: as caixas inteiras, mais o kg das frações em caixas e o resto em kg ("2 cx e 5 kg").
  # Devolve [caixas, kg avulsos], ou [nil, 0] sem kg por embalagem.
  def packages_for(raw_material, unit, need, net_kg)
    per_package = raw_material.kg_per_package
    return [ nil, 0 ] unless unit == "kg" && per_package.to_d.positive?
    return [ 0, 0 ] unless net_kg.positive?

    gross_by_product = need[:breakdown].group_by(&:product).transform_values do |lines|
      lines.sum { |b| gross_kg(b.product, b.quantity) }
    end
    whole_boxes = 0
    fraction_kg = 0
    gross_by_product.each do |product, gross|
      share = (net_kg * gross / need[:kg]).round(3)
      product.fraction_rounding? ? fraction_kg += share : whole_boxes += (share / per_package).ceil
    end
    fraction_boxes = (fraction_kg / per_package).floor
    [ whole_boxes + fraction_boxes, (fraction_kg - fraction_boxes * per_package).round(3) ]
  end

  # Mesmo kg que add_quantity soma para a linha (in natura, ou processado vezes o fator).
  def gross_kg(product, quantity)
    factor = product.raw_material.multiply_factor
    product.raw? || factor.nil? ? quantity : quantity * factor
  end

  # Contagens feitas depois da compra anterior (ou até a primeira compra) substituem o que sobrou.
  def apply_counts(stock, counts, previous_date, date)
    counts.each do |count|
      next if count.date > date || (previous_date && count.date <= previous_date)

      stock[count.raw_material_id] = count.kg
    end
  end
end
