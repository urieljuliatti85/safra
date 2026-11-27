# Volume total de compra por dia de compra (CEASA) e matéria-prima, como no passo 3 da esteira simplificada (o MVP):
# os processados convertidos em matéria-prima pelo fator, mais os pedidos in natura. Cada compra abastece a produção
# do dia da compra até a véspera da compra seguinte, pelo dia de execução de cada item (escolhido na Programação ou,
# sem escolha, a véspera da entrega).
# No MVP não há abate de estoque nem caixas: ready e stock_kg ficam vazios, net_kg é o volume total e packages é nil
# (os campos continuam no Need para quem os lê; o abate e as caixas entram depois do MVP).
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
      purchase_dates = PurchaseCalendar.new(@company).dates
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
      production_date = line.execution_on
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

  # O volume total de cada matéria-prima (esteira simplificada, passo 3): processado vezes o fator, in natura como veio.
  def finalize(raw_needs, purchase_dates)
    purchase_dates.index_with do |date|
      raw_needs[date].map do |(raw_material, unit), need|
        kg = need[:breakdown].sum { |b| line_kg(b.product, unit, b.quantity) }
        Need.new(
          raw_material: raw_material, unit: unit,
          processed_quantity: need[:processed], raw_quantity: need[:raw], ready: {},
          kg: kg, stock_kg: 0, net_kg: kg,
          packages: nil, loose_kg: 0, loose_units: 0, net_packages: nil,
          missing_factor: need[:missing_factor],
          breakdown: need[:breakdown]
        )
      end.sort_by { |need| [ need.raw_material.supplier&.name.to_s, need.raw_material.name, need.unit ] }
    end
  end

  # Mesmo kg que add_quantity soma para a linha: in natura e unidade diferente de kg entram como estão; processado em
  # kg, vezes o fator.
  def line_kg(product, unit, quantity)
    factor = product.raw_material.multiply_factor
    product.raw? || unit != "kg" || factor.nil? ? quantity : quantity * factor
  end
end
