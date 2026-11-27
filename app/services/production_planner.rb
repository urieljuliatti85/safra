# Calcula a produção de um dia: o que produzir por produto (com a abertura por cliente e entrega)
# e as caixas a aprontar por matéria-prima. Nada é digitado: tudo sai das linhas de pedido.
# Referência: funções producao() e aprontes() do protótipo (docs/prototipo/safra.html, privado).
class ProductionPlanner
  # measure: a medida que orienta o preparo (Cut#measure_for). Duas medidas do mesmo produto são dois itens (R2.4, D24).
  Item = Data.define(:product, :measure, :quantity, :unit, :breakdown) do
    # A medida pedida, quando não é a de referência do corte. Ela entra no nome do item e na comparação entre versões,
    # para distinguir duas medidas do mesmo produto; a de referência (ou vazia, nas versões de antes da D24) não.
    def custom_measure
      measure if measure.present? && Cut.measure_key(measure) != Cut.measure_key(product.cut&.reference_measure)
    end

    def label = custom_measure ? "#{product.name} · #{custom_measure}" : product.name
  end
  # via: nome da mistura de onde veio a quantidade, quando o ingrediente veio de uma mistura (R2.9, D25).
  Breakdown = Data.define(:customer, :delivery_date, :quantity, :via) do
    def initialize(customer:, delivery_date:, quantity:, via: nil) = super
  end
  # Uma parte do pedido a produzir: a linha do pedido ou, numa mistura, a parte de um ingrediente (D25).
  Portion = Data.define(:product, :measure, :unit, :quantity, :customer, :delivery_date, :via)
  # Soma dos percentuais tratada como a mistura inteira: o Vinagrete tem três partes iguais de 33,3333% (R1.20).
  WHOLE_MIX = (BigDecimal("99.99")..BigDecimal("100.01"))
  # Relação de descasque e preparo (aprontes): total a preparar por vegetal e unidade (R3.8, R3.11, D42). Em kg, com o kg
  # por caixa descascada, vira caixas; em unidade (laranja descascada), fica a quantidade.
  Apronte = Data.define(:raw_material, :unit, :quantity, :boxes) do
    def kg = unit == "kg" ? quantity : nil
  end
  Result = Data.define(:date, :items, :delivery_dates, :aprontes) do
    def item_for(product_code)
      items.find { |item| item.product.code == product_code }
    end

    # Setores com produção no dia, na ordem de Cut::SECTORS, mais "aprontes" se houver caixas a aprontar.
    def sectors
      present = items.map { |item| item.product.sector }
      Cut::SECTORS.select { |sector| present.include?(sector) } + (aprontes.any? ? [ APRONTES ] : [])
    end

    # Só a lista de um setor (ou só os aprontes), para a tela e o PDF de cada bancada.
    def for_sector(sector)
      return self if sector.blank?
      return with(items: []) if sector == APRONTES

      kept = items.select { |item| item.product.sector == sector }
      with(items: kept, delivery_dates: kept.flat_map { |item| item.breakdown.map(&:delivery_date) }.uniq.sort, aprontes: [])
    end
  end
  APRONTES = "aprontes".freeze

  def initialize(company:, date:)
    @company = company
    @date = date.to_date
  end

  def call
    ActsAsTenant.with_tenant(@company) { self.class.result(@date, build_items) }
  end

  # Linhas in natura entregues neste dia ou que contariam para ele pela antecedência:
  # não passam pela produção, vão direto para a compra.
  def raw_lines
    ActsAsTenant.with_tenant(@company) do
      window_lines.select do |line|
        line.product.raw? && (line.delivery_date == @date || line.product.production_date_for(line.delivery_date) == @date)
      end
    end
  end

  # A linha do pedido, ou as partes dos ingredientes, quando ela é uma mistura em kg com a composição inteira (percentual
  # sobre o peso, R1.19, R1.20). Os ingredientes ficam no dia de produção da mistura, na medida que a composição dá a eles
  # (os 3 mm dos ralados e picados, R1.20, D30) ou, sem ela, na do produto. Mistura sem composição, com composição que não soma 100% (aviso na conferência) ou pedida em outra unidade
  # continua como produto pronto, para nenhuma parte do pedido sumir. Também usada pela visão da semana (WeekOverview).
  def self.portions(line)
    portion = Portion.new(product: line.product, measure: line.measure, unit: line.unit, quantity: line.quantity,
                          customer: line.order.customer, delivery_date: line.delivery_date, via: nil)
    components = line.product.components
    return [ portion ] unless line.unit == "kg" && whole_mix?(components)

    split(line.quantity, components).map do |component, quantity|
      portion.with(product: component.component, measure: component.measure, quantity: quantity, via: line.product.name)
    end
  end

  def self.whole_mix?(components) = components.any? && WHOLE_MIX.cover?(components.sum(&:percentage))

  # Quantidade de cada ingrediente, em decimal(10,3). A diferença do arredondamento vai para o ingrediente de maior
  # percentual (o primeiro), para os ingredientes somarem o pedido.
  def self.split(quantity, components)
    total = components.sum(&:percentage)
    parts = components.map { |c| [ c, (quantity * c.percentage / total).round(3) ] }
    parts[0][1] += quantity - parts.sum(&:last)
    parts
  end
  private_class_method :split

  def self.measure_of(portion) = portion.product.measure_for(portion.measure)

  # Também monta a versão enviada (ProductionPlan#to_result): entregas e aprontes saem dos itens, não do pedido.
  def self.result(date, items)
    items = items.sort_by { |item| [ item.product.sector.to_s, item.product.name, item.measure.to_s ] }
    Result.new(
      date: date,
      items: items,
      delivery_dates: items.flat_map { |item| item.breakdown.map(&:delivery_date) }.uniq.sort,
      aprontes: aprontes(items)
    )
  end

  # Em kg, como sempre: processado fora dos descascados inteiros, com o kg por caixa descascada. Em unidade: os cortes
  # que passam pelo descasque (Cut#peeled, D42), somados por vegetal.
  def self.aprontes(items)
    totals = Hash.new(0)
    items.each do |item|
      product = item.product
      next unless apronte?(item, product)

      totals[[ product.raw_material, item.unit ]] += item.quantity
    end
    totals.map do |(raw_material, unit), quantity|
      boxes = (quantity / raw_material.kg_per_peeled_box).round if unit == "kg"
      Apronte.new(raw_material: raw_material, unit: unit, quantity: quantity, boxes: boxes)
    end.sort_by { |apronte| [ apronte.raw_material.name, apronte.unit ] }
  end

  def self.apronte?(item, product)
    return product.sector != "descasc" && product.raw_material.kg_per_peeled_box.present? if item.unit == "kg"

    product.cut&.peeled?
  end
  private_class_method :apronte?

  private

  # Soma os clientes do dia numa linha por produto, medida e unidade (R2.1, R2.2, R2.4, R2.5), com a parte de cada um.
  # As misturas entram pelos ingredientes, somados com o mesmo ingrediente pedido avulso (R2.8, D25).
  def build_items
    grouped = candidate_lines.flat_map { |line| portions(line) }.group_by { |p| [ p.product, Cut.measure_key(measure_of(p)), p.unit ] }
    grouped.map do |(product, _, unit), portions|
      Item.new(
        product: product,
        measure: shown_measure(portions),
        quantity: portions.sum(&:quantity),
        unit: unit,
        breakdown: portions.sort_by { |p| [ p.delivery_date, p.customer.code, p.via.to_s ] }.map do |p|
          Breakdown.new(customer: p.customer, delivery_date: p.delivery_date, quantity: p.quantity, via: p.via)
        end
      )
    end
  end

  def portions(line) = self.class.portions(line)

  def measure_of(portion) = self.class.measure_of(portion)

  # A mesma medida pode vir escrita de jeitos diferentes ("12x12", "12 × 12 mm"): mostra a escrita mais usada no grupo
  # e, no empate, a primeira em ordem alfabética, para o nome não depender da ordem das linhas no banco.
  def shown_measure(portions) = portions.map { |p| measure_of(p) }.tally.min_by { |measure, count| [ -count, measure.to_s ] }.first

  def candidate_lines
    day_lines.reject { |line| line.product.raw? }
  end

  def day_lines
    window_lines.select { |line| line.product.production_date_for(line.delivery_date) == @date }
  end

  # Só entregas dentro da janela possível: produção é no máximo `lead_days` + fim de semana antes da entrega.
  def window_lines
    @window_lines ||= OrderLine.where("quantity > 0")
                               .where(delivery_date: @date..(@date + 7))
                               .includes({ order: :customer }, product: [ :cut, :production_rule, :raw_material, { components: { component: %i[cut raw_material] } } ])
                               .to_a
  end
end
