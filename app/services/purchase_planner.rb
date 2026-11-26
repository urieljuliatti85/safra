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
    :packages,           # caixas/sacos a comprar (soma dos itens já arredondados por produto); nil se não dá para calcular
    :net_packages,       # necessidade em caixas antes do arredondamento (para exibição)
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

        # Calcula caixas por item do breakdown (respeitando arredondamento por produto) e soma
        packages_sum = 0
        net_packages_sum = 0
        if unit == "kg" && raw_material.kg_per_package.present? && raw_material.kg_per_package > 0
          need[:breakdown].each do |b|
            # Distribui o estoque proporcionalmente? Não - o estoque já foi abatido do total.
            # Para o breakdown, calculamos a parte de cada produto no net_kg
            # Proporção do produto na necessidade bruta total (em kg)
            item_kg = b.product.raw? ? b.quantity : (b.quantity * (b.product.raw_material.multiply_factor || 1))
            total_kg = need[:kg]
            next if total_kg.zero?
            item_net_kg = (net_kg * item_kg / total_kg).round(3)

            net_packages = item_net_kg / raw_material.kg_per_package
            net_packages_sum += net_packages

            if b.product.whole_box_rounding?
              packages_sum += net_packages.ceil
            else
              packages_sum += net_packages
            end
          end
        end

        packages_val = if unit == "kg" && raw_material.kg_per_package.present? && raw_material.kg_per_package > 0
          (packages_sum > 0 ? packages_sum : 0)
        end
        net_packages_val = if unit == "kg" && raw_material.kg_per_package.present? && raw_material.kg_per_package > 0
          net_packages_sum > 0 ? net_packages_sum : 0
        end

        Need.new(
          raw_material: raw_material, unit: unit,
          processed_quantity: need[:processed], raw_quantity: need[:raw],
          kg: need[:kg], stock_kg: stock_kg, net_kg: net_kg,
          packages: packages_val,
          net_packages: net_packages_val,
          missing_factor: need[:missing_factor],
          breakdown: need[:breakdown]
        )
      end.sort_by { |need| [ need.raw_material.supplier&.name.to_s, need.raw_material.name, need.unit ] }
    end
  end

  # Contagens feitas depois da compra anterior (ou até a primeira compra) substituem o que sobrou.
  def apply_counts(stock, counts, previous_date, date)
    counts.each do |count|
      next if count.date > date || (previous_date && count.date <= previous_date)

      stock[count.raw_material_id] = count.kg
    end
  end
end
