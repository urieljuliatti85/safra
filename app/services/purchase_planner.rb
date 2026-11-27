# Calcula a necessidade de compra por dia de compra (CEASA) e matéria-prima.
# Cada compra abastece a produção do dia da compra até a véspera da compra seguinte.
# O estoque da câmara fria é abatido antes, na ordem das compras.
# Referência: função necessidade() do protótipo (docs/prototipo/safra.html, privado).
class PurchasePlanner
  Need = Data.define(
    :raw_material, :unit,
    :processed_quantity, # pedido em produtos processados (na unidade do pedido)
    :raw_quantity,       # pedido in natura (na unidade do pedido)
    :ready,              # { produto => quantidade } de produto pronto abatida do pedido, antes do fator (R3.8)
    :kg,                 # necessidade em kg in natura, já sem o produto pronto
    :stock_kg,           # abatido da câmara fria
    :net_kg,             # necessidade líquida em kg
    :packages,           # caixas/sacos inteiros a comprar, somados por produto (R3.9); nil se não dá para calcular
    :loose_kg,           # kg além das caixas, dos produtos comprados em fração (R3.9: "2 caixas e 5 kg")
    :loose_units,        # unidades além das caixas, da fruta em unidade comprada em fração (R3.10: "2 cx e 20 un")
    :net_packages,       # líquido em caixas, antes do arredondamento (para a tela)
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

      need = (needs[purchase_date][[ product.raw_material, line.unit ]] ||= { processed: 0, raw: 0, missing_factor: false, breakdown: [] })
      add_quantity(need, product, line)
      need[:breakdown] << Breakdown.new(
        customer: line.order.customer, product: product, delivery_date: line.delivery_date,
        production_date: production_date, quantity: line.quantity, unit: line.unit
      )
    end
    [ needs, uncovered ]
  end

  # Soma o pedido processado e o in natura; o kg é calculado no finalize, depois do produto pronto.
  def add_quantity(need, product, line)
    if product.raw?
      need[:raw] += line.quantity
    else
      need[:processed] += line.quantity
      raw_material = product.raw_material
      need[:missing_factor] = true if line.unit == "kg" ? raw_material.multiply_factor.nil? : !raw_material.converts_units?(line.unit)
    end
  end

  # A conta segue a ordem da esteira (R3.8, D39): pedido, menos o saldo de produto pronto, vezes o fator, menos o saldo
  # de matéria-prima, e só então o arredondamento por produto (R3.9). Cada saldo vale para a compra assim: a contagem
  # mais recente até o dia da compra entra nela, e o que sobra depois de abater vai para a compra seguinte, a não ser
  # que uma contagem nova (feita depois da compra anterior) o substitua. O produto pronto abate só o pedido na unidade
  # do produto; a matéria-prima, só o que é pedido em kg.
  def finalize(raw_needs, purchase_dates)
    counts = StockCount.order(:date, :id).to_a
    ready_counts = ProductStockCount.order(:date, :id).to_a
    stock = Hash.new(0)
    ready = Hash.new(0)
    previous_date = nil
    purchase_dates.index_with do |date|
      apply_counts(stock, counts, previous_date, date, :raw_material_id, :kg)
      apply_counts(ready, ready_counts, previous_date, date, :product_id, :quantity)
      previous_date = date
      raw_needs[date].map do |(raw_material, unit), need|
        kg_by_product = need[:breakdown].group_by(&:product).transform_values { |lines| lines.sum { |b| line_kg(b.product, unit, b.quantity) } }
        ready_used = deduct_ready(ready, need[:breakdown], unit, kg_by_product)
        kg = kg_by_product.values.sum
        stock_kg = unit == "kg" ? [ stock[raw_material.id], kg ].min : 0
        stock[raw_material.id] -= stock_kg if stock_kg.positive?
        net_kg = [ kg - stock_kg, 0 ].max

        packages, loose_kg, loose_units = unit == "kg" ? packages_for(raw_material, unit, kg_by_product, kg, net_kg) + [ 0 ] : unit_packages_for(raw_material, unit, kg_by_product)

        Need.new(
          raw_material: raw_material, unit: unit,
          processed_quantity: need[:processed], raw_quantity: need[:raw], ready: ready_used,
          kg: kg, stock_kg: stock_kg, net_kg: net_kg,
          packages: packages, loose_kg: loose_kg, loose_units: loose_units,
          net_packages: packages && net_packages(raw_material, unit, net_kg),
          missing_factor: need[:missing_factor],
          breakdown: need[:breakdown]
        )
      end.sort_by { |need| [ need.raw_material.supplier&.name.to_s, need.raw_material.name, need.unit ] }
    end
  end

  # Abate o produto pronto do pedido de cada produto processado, antes do fator. Só quando o pedido está na unidade do
  # produto (quilos e unidades não se misturam). Muda kg_by_product e o saldo; devolve { produto => quantidade abatida }.
  def deduct_ready(ready, breakdown, unit, kg_by_product)
    breakdown.group_by(&:product).each_with_object({}) do |(product, lines), used|
      next if product.raw? || product.unit != unit || !ready[product.id].positive?

      quantity = [ ready[product.id], lines.sum(&:quantity) ].min
      ready[product.id] -= quantity
      kg_by_product[product] -= line_kg(product, unit, quantity)
      used[product] = quantity
    end
  end

  # Arredondamento por produto (R3.9, D41): o kg líquido da matéria-prima é repartido entre os produtos na proporção
  # do kg de cada um (já sem o produto pronto). Produto de caixa inteira arredonda a sua parte para cima; produto em
  # fração entra com o kg exato. Soma tudo: as caixas inteiras, mais o kg das frações em caixas e o resto em kg
  # ("2 cx e 5 kg"). Devolve [caixas, kg avulsos], ou [nil, 0] sem kg por embalagem.
  def packages_for(raw_material, unit, kg_by_product, kg, net_kg)
    per_package = raw_material.kg_per_package
    return [ nil, 0 ] unless unit == "kg" && per_package.to_d.positive?
    return [ 0, 0 ] unless net_kg.positive?

    whole_boxes = 0
    fraction_kg = 0
    kg_by_product.each do |product, product_kg|
      share = (net_kg * product_kg / kg).round(3)
      product.fraction_rounding? ? fraction_kg += share : whole_boxes += (share / per_package).ceil
    end
    fraction_boxes = (fraction_kg / per_package).floor
    [ whole_boxes + fraction_boxes, (fraction_kg - fraction_boxes * per_package).round(3) ]
  end

  # Fruta pedida por unidade (R3.10, D40). Comprada por unidade (melancia): compra as unidades pedidas. Comprada em
  # caixa com as unidades por caixa cadastradas (laranja, 100): cada produto de caixa inteira arredonda a sua parte para
  # cima; os de fração somam as unidades e compram as caixas inteiras e o resto em unidades. Devolve
  # [caixas ou unidades, 0, unidades avulsas], ou [nil, 0, 0] quando não converte (fica o alerta).
  def unit_packages_for(raw_material, unit, units_by_product)
    return [ nil, 0, 0 ] unless raw_material.converts_units?(unit)

    units = units_by_product.values.sum
    return [ units.ceil, 0, 0 ] if raw_material.purchase_package == "un"

    per_package = raw_material.units_per_package
    whole_boxes = 0
    fraction_units = 0
    units_by_product.each do |product, quantity|
      product.fraction_rounding? ? fraction_units += quantity : whole_boxes += (quantity / per_package).ceil
    end
    fraction_boxes = (fraction_units / per_package).floor
    [ whole_boxes + fraction_boxes, 0, (fraction_units - fraction_boxes * per_package).ceil ]
  end

  # O líquido em caixas antes de arredondar: kg ÷ kg por caixa, ou unidades ÷ unidades por caixa.
  def net_packages(raw_material, unit, net)
    return (net / raw_material.kg_per_package).round(2) if unit == "kg"
    return net if raw_material.purchase_package == "un"

    (net / raw_material.units_per_package).round(2)
  end

  # Mesmo kg que add_quantity soma para a linha: in natura e unidade diferente de kg entram como estão; processado em
  # kg, vezes o fator.
  def line_kg(product, unit, quantity)
    factor = product.raw_material.multiply_factor
    product.raw? || unit != "kg" || factor.nil? ? quantity : quantity * factor
  end

  # Contagens feitas depois da compra anterior (ou até a primeira compra) substituem o que sobrou.
  def apply_counts(stock, counts, previous_date, date, key, value)
    counts.each do |count|
      next if count.date > date || (previous_date && count.date <= previous_date)

      stock[count.public_send(key)] = count.public_send(value)
    end
  end
end
