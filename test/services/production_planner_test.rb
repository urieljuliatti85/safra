require "test_helper"

class ProductionPlannerTest < ActiveSupport::TestCase
  test "domingo não tem produção: entrega na segunda produzida de véspera cai para sábado" do
    # 12/10/2026 é segunda; 11/10 é domingo e 10/10 é sábado.
    friday_plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 10)).call
    sunday_plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 11)).call
    assert_empty sunday_plan.items
    assert_includes friday_plan.delivery_dates, Date.new(2026, 10, 12)
  end

  test "ralados são produzidos no dia da entrega e cubinhos na véspera" do
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    assert_equal [ Date.new(2026, 10, 13) ], plan.item_for("cenoura_ralada").breakdown.reject(&:via).map(&:delivery_date).uniq
    assert_equal [ Date.new(2026, 10, 14) ], plan.item_for("baroa_cubinhos").breakdown.map(&:delivery_date).uniq
  end

  test "lista de um setor só tem os itens dele; a dos aprontes, só as caixas" do
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    assert_equal Cut::SECTORS.select { |s| plan.items.any? { |i| i.product.sector == s } } + [ "aprontes" ], plan.sectors

    ralpic = plan.for_sector("ralpic")
    assert ralpic.items.any?
    assert ralpic.items.all? { |item| item.product.sector == "ralpic" }
    assert_empty ralpic.aprontes
    # 14/10: a Yaksoba entregue em 14/10 é produzida em 13/10, e os ingredientes ficam no dia dela (D25).
    assert_equal [ Date.new(2026, 10, 13), Date.new(2026, 10, 14) ], ralpic.delivery_dates

    aprontes = plan.for_sector("aprontes")
    assert_empty aprontes.items
    assert_equal plan.aprontes, aprontes.aprontes
    assert_same plan, plan.for_sector(nil)
  end

  test "aprontes: caixas = ROUND(kg processado / kg por caixa descascada)" do
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    batata = plan.aprontes.find { |a| a.raw_material.code == "batata" }
    assert_equal 36, batata.kg
    assert_equal (36 / 30.0).round, batata.boxes
  end

  test "in natura não entra na produção; as linhas in natura do dia somam a entrega do dia e a da antecedência" do
    ActsAsTenant.with_tenant(company) do
      order = Order.create!(customer: Customer.first, week_start: Date.new(2026, 11, 2))
      raw = Product.find_by!(product_group: "raw")
      [ 3, 4, 5 ].each { |day| order.lines.create!(product: raw, delivery_date: Date.new(2026, 11, day), quantity: 10, unit: "kg") }
    end

    planner = ProductionPlanner.new(company: company, date: Date.new(2026, 11, 3))
    assert_empty planner.call.items
    # 03/11 é entregue no dia; 04/11 conta para 03/11 pela antecedência de 1 dia; 05/11 é de outro dia.
    assert_equal [ Date.new(2026, 11, 3), Date.new(2026, 11, 4) ], planner.raw_lines.map(&:delivery_date).sort
  end

  test "breakdown guarda cliente e data de entrega" do
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    assert_equal 4, plan.item_for("batata_cubos").quantity
    assert_equal %w[hbp], plan.item_for("batata_cubos").breakdown.map { |b| b.customer.code }
  end

  test "os planejadores carregam clientes e matérias-primas de uma vez, sem uma consulta por linha" do
    date = Date.new(2026, 10, 13)
    count_queries = lambda do |&block|
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { ActiveRecord::Base.uncached(&block) }
      queries
    end

    assert_operator count_queries.call { PurchasePlanner.new(company: company).call }, :<=, 11
    assert_operator count_queries.call { ProductionPlanner.new(company: company, date: date).call }, :<=, 10
    assert_operator count_queries.call { ScheduleBuilder.new(company: company, date: date).call }, :<=, 8
  end

  # Batata em cubinhos de 13/10 (entrega 14/10): Bom Pastor 25 kg e Horizonte Norte 7 kg.
  def measure_batata_cubinhos(customer_code, measure)
    ActsAsTenant.with_tenant(company) do
      OrderLine.joins(:product, order: :customer)
               .where(products: { code: "batata_cubinhos" }, customers: { code: customer_code }, delivery_date: Date.new(2026, 10, 14))
               .update_all(measure: measure)
    end
  end

  test "medidas diferentes do mesmo produto são itens separados; a parte de cada cliente fica (R2.4, D24)" do
    assert_equal 1, measure_batata_cubinhos("hnorte", "12 × 12 mm")
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    items = plan.items.select { |i| i.product.code == "batata_cubinhos" }
    assert_equal [ [ "10 × 10 × 10 mm", 25, %w[hbp] ], [ "12 × 12 mm", 7, %w[hnorte] ] ],
                 items.map { |i| [ i.measure, i.quantity, i.breakdown.map { |b| b.customer.code } ] }
    assert_equal [ "Batata em cubinhos", "Batata em cubinhos · 12 × 12 mm" ], items.map(&:label)
  end

  test "medida vazia e a de referência escrita de outro jeito são a mesma linha (R1.14, D24)" do
    assert_equal 1, measure_batata_cubinhos("hbp", "10x10x10")
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    item = plan.items.find { |i| i.product.code == "batata_cubinhos" }
    assert_equal [ 1, 32, "10 × 10 × 10 mm" ], [ plan.items.count { |i| i.product.code == "batata_cubinhos" }, item.quantity, item.measure ]
  end

  test "palito sai 40 × 10 mm mesmo com outra medida no pedido (R2.11, D24)" do
    ActsAsTenant.with_tenant(company) do
      OrderLine.joins(:product).where(products: { code: "cenoura_palitos" }, delivery_date: Date.new(2026, 10, 14)).update_all(measure: "10 × 10 × 60 mm")
    end
    plan = ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call
    items = plan.items.select { |i| i.product.code == "cenoura_palitos" }
    assert_equal [ [ "40 × 10 mm", "Cenoura em palitos" ] ], items.map { |i| [ i.measure, i.label ] }
  end

  test "a mesma medida escrita de dois jeitos é uma linha, com o nome estável, sem depender da ordem do banco (D24)" do
    assert_equal 1, measure_batata_cubinhos("hbp", "12x12")
    assert_equal 1, measure_batata_cubinhos("hnorte", "12 × 12 mm")
    shown = -> { ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call.items.select { |i| i.product.code == "batata_cubinhos" }.map { |i| [ i.measure, i.quantity ] } }
    assert_equal [ [ "12 × 12 mm", 32 ] ], shown.call
    ActsAsTenant.with_tenant(company) do
      OrderLine.joins(:product, order: :customer).where(products: { code: "batata_cubinhos" }, customers: { code: "hbp" }, delivery_date: Date.new(2026, 10, 14))
               .update_all("quantity = order_lines.quantity + 1")
    end
    assert_equal [ [ "12 × 12 mm", 33 ] ], shown.call
  end

  # Pedidos da quinta 22/10 (produzidos na quarta 21/10), semana sem outros pedidos no seed, para os casos de mistura (D25).
  MIX_DAY = Date.new(2026, 10, 22)

  def mix_order(lines)
    ActsAsTenant.with_tenant(company) do
      assert_empty OrderLine.where(delivery_date: (MIX_DAY - 1)..(MIX_DAY + 7)) # a janela da produção de 21/10
      lines.each do |customer_code, product_code, quantity, unit|
        order = Order.find_or_create_by!(customer: Customer.find_by!(code: customer_code), week_start: Date.new(2026, 10, 19))
        OrderLine.create!(order: order, product: Product.find_by!(code: product_code), delivery_date: MIX_DAY, quantity: quantity, unit: unit || "kg")
      end
    end
    ProductionPlanner.new(company: company, date: MIX_DAY - 1).call
  end

  test "mistura entra pelos ingredientes, somada com o avulso de mesmo corte e medida (R2.8, D25)" do
    plan = mix_order([ [ "hbp", "seleta", 20 ], [ "hnorte", "cenoura_cubinhos", 10 ] ])
    assert_nil plan.item_for("seleta"), "a mistura não aparece como produto pronto"
    cenoura = plan.item_for("cenoura_cubinhos")
    assert_equal [ 17, "10 × 10 × 10 mm" ], [ cenoura.quantity, cenoura.measure ]
    assert_equal [ [ "hbp", 7, "Seleta jardineira" ], [ "hnorte", 10, nil ] ], cenoura.breakdown.map { |b| [ b.customer.code, b.quantity, b.via ] }
    assert_equal [ 10, 3 ], [ plan.item_for("batata_cubinhos").quantity, plan.item_for("vagem_cubinhos").quantity ]
    assert_equal [ "Seleta jardineira" ], plan.item_for("vagem_cubinhos").breakdown.map(&:via)
  end

  test "Vinagrete: três partes iguais que somam o pedido (R1.20, D25)" do
    plan = mix_order([ [ "hbp", "vinagrete", 20 ] ])
    parts = %w[tomate_cubinhos pimentao_verde_cubinhos cebola_cubinhos].map { |code| plan.item_for(code).quantity }
    assert_equal 20, parts.sum
    assert(parts.all? { |q| (q - BigDecimal("6.667")).abs <= BigDecimal("0.001") })
  end

  test "mistura pedida em outra unidade continua como produto pronto (percentual é sobre o peso)" do
    plan = mix_order([ [ "hbp", "seleta", 4, "un" ] ])
    assert_equal [ 4, "un" ], [ plan.item_for("seleta").quantity, plan.item_for("seleta").unit ]
    assert_nil plan.item_for("cenoura_cubinhos")
  end

  test "mistura sem composição cadastrada continua como produto pronto" do
    ActsAsTenant.with_tenant(company) { ProductComponent.where(product: Product.find_by!(code: "seleta")).delete_all }
    plan = mix_order([ [ "hbp", "seleta", 20 ] ])
    assert_equal 20, plan.item_for("seleta").quantity
  end

  test "a versão enviada guarda de qual mistura veio cada parte (D25)" do
    plan = mix_order([ [ "hbp", "seleta", 20 ], [ "hnorte", "cenoura_cubinhos", 10 ] ])
    sent = PlanPublisher.production(company: company, result: plan)
    ActsAsTenant.with_tenant(company) do
      cenoura = ProductionPlan.find(sent.id).to_result.item_for("cenoura_cubinhos")
      assert_equal [ "Seleta jardineira", nil ], cenoura.breakdown.map(&:via)
      assert_empty PlanDiff.production(ProductionPlan.find(sent.id), ProductionPlanner.new(company: company, date: MIX_DAY - 1).call)
    end
  end

  test "composição que não soma 100% deixa a mistura pronta, inteira, e a conferência avisa (D25)" do
    ActsAsTenant.with_tenant(company) { ProductComponent.where(component: Product.find_by!(code: "batata_cubinhos")).delete_all }
    plan = mix_order([ [ "hbp", "seleta", 20 ] ])
    assert_equal 20, plan.item_for("seleta").quantity
    assert_nil plan.item_for("cenoura_cubinhos")
    alert = ConferenceChecker.new(company: company, week: Date.new(2026, 10, 19)).call.find { |a| a.kind == "Mistura" }
    assert_match "Seleta jardineira: a composição soma 50%, e não 100%", alert.message
    assert_equal "Revisar a composição", alert.action.label
  end
end
