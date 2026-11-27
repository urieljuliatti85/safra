require "test_helper"

# "Apagar pedido": os itens do cliente na semana, ou num dia, saem, digitados ou importados, e o que eles geraram sai do
# processo: Programação, Planilha de Produção, Compras e Pesagem voltam sozinhas, as versões enviadas com itens dele são
# apagadas e a planilha que ficou vazia volta a pendente, sem os apelidos que criou. O Estoque não muda.
class OrderClearTest < ActionDispatch::IntegrationTest
  WEEK = Date.new(2026, 10, 12)

  setup do
    sign_in_as(user_for(:office))
    @hbp, @hnorte = ActsAsTenant.with_tenant(company) { [ Customer.find_by!(code: "hbp"), Customer.find_by!(code: "hnorte") ] }
  end

  def lines(customer)
    ActsAsTenant.with_tenant(company) { OrderLine.joins(:order).where(orders: { customer_id: customer.id, week_start: WEEK }).where("quantity > 0").count }
  end

  test "o botão aparece para o escritório, com a semana e os dias do pedido, e some com o pedido vazio" do
    get orders_path(customer: "hbp", week: WEEK)
    assert_select "form[action^='#{order_clear_path}'] button", /Apagar pedido/
    assert_select "form[action^='#{order_clear_path}'][data-turbo-confirm*='Bom Pastor']"
    assert_select "select#apagar-pedido-dia option", "Semana inteira"
    assert_select "select#apagar-pedido-dia option[value='2026-10-13']", "Ter 13/10"

    delete order_clear_path(customer: "hbp", week: WEEK)
    get orders_path(customer: "hbp", week: WEEK)
    assert_select "form[action^='#{order_clear_path}']", false
  end

  test "apaga todos os itens do cliente na semana, as versões enviadas com itens dele e fica no histórico" do
    plan_with_hbp, plan_without = ActsAsTenant.with_tenant(company) do
      with_hbp = PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call)
      without = PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: Date.new(2026, 10, 25)).call)
      [ with_hbp, without ]
    end
    assert_operator lines(@hbp), :>, 0
    others = lines(@hnorte)

    delete order_clear_path(customer: "hbp", week: WEEK)
    assert_redirected_to orders_path(customer: "hbp", week: WEEK)
    follow_redirect!
    assert_match "Pedido de Bom Pastor da semana de 12/10 apagado", response.body
    assert_match "Versões enviadas apagadas: Produção de 13/10 v#{plan_with_hbp.version}", response.body

    assert_equal 0, lines(@hbp)
    assert_equal others, lines(@hnorte), "o pedido dos outros clientes não muda"
    ActsAsTenant.with_tenant(company) do
      assert_not ProductionPlan.exists?(plan_with_hbp.id)
      assert ProductionPlan.exists?(plan_without.id)
      version = Order.find_by!(customer: @hbp, week_start: WEEK).versions.newest_first.first
      assert_equal "Pedido apagado", version.source_label
      assert_empty ProductionPlanner.new(company: company, date: Date.new(2026, 10, 13)).call.items.flat_map(&:breakdown).select { |b| b.customer.code == "hbp" }
    end
  end

  test "apagar um dia tira só os itens daquele dia de entrega e as versões com itens dele" do
    day = Date.new(2026, 10, 14)
    plan_13, plan_12 = ActsAsTenant.with_tenant(company) do
      [ Date.new(2026, 10, 13), Date.new(2026, 10, 12) ].map do |date|
        PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: date).call)
      end
    end
    before = ActsAsTenant.with_tenant(company) { Order.find_by!(customer: @hbp, week_start: WEEK).lines.where("quantity > 0").group(:delivery_date).count }
    assert before[day].to_i.positive?

    delete order_clear_path(customer: "hbp", week: WEEK, day: day.iso8601)
    follow_redirect!
    assert_match "Pedido de Bom Pastor de Qua 14/10 apagado: #{before[day]} itens", response.body

    after = ActsAsTenant.with_tenant(company) { Order.find_by!(customer: @hbp, week_start: WEEK).lines.where("quantity > 0").group(:delivery_date).count }
    assert_equal before.except(day), after
    ActsAsTenant.with_tenant(company) do
      assert_not ProductionPlan.exists?(plan_13.id), "a véspera (13/10) tinha itens do Bom Pastor entregues em 14/10"
      assert ProductionPlan.exists?(plan_12.id), "a de 12/10 não tinha item entregue em 14/10"
    end
  end

  test "dia fora da semana não apaga nada" do
    delete order_clear_path(customer: "hbp", week: WEEK, day: "2026-10-25")
    follow_redirect!
    assert_match "Escolha um dia desta semana.", response.body
  end

  test "o Estoque não muda" do
    count = ActsAsTenant.with_tenant(company) do
      ProductStockCount.create!(product: Product.find_by!(code: "cenoura_cubinhos"), date: Date.new(2026, 10, 13), quantity: 2)
    end
    delete order_clear_path(customer: "hbp", week: WEEK)
    assert ActsAsTenant.with_tenant(company) { ProductStockCount.exists?(count.id) }
  end

  test "a planilha importada que ficou vazia volta a pendente e os apelidos que ela criou saem" do
    travel_to Time.zone.local(2026, 10, 5, 9)
    record = ActsAsTenant.with_tenant(company) do
      imported = OrderImports::Importer.new(company: company, customer: @hbp, path: file_fixture("pedido_sem_unidade.xlsx").to_s,
                                            filename: "pedido_sem_unidade.xlsx").call
      pitaya = imported.rows.index { |r| r["name"].start_with?("Pitaya") }
      assert OrderImports::Applier.new(import: imported, mappings: { pitaya.to_s => Product.find_by!(code: "abobora_lascas").id.to_s }).call.ok?
      assert CustomerAlias.exists?(customer: @hbp, name_in_order: "Pitaya Fatiada Especial")
      imported
    end

    delete order_clear_path(customer: "hbp", week: WEEK)
    follow_redirect!
    assert_match "Planilha de novo pendente, sem os apelidos que criou: pedido_sem_unidade.xlsx", response.body
    ActsAsTenant.with_tenant(company) do
      assert_equal "pending", record.reload.status
      assert_not CustomerAlias.exists?(customer: @hbp, name_in_order: "Pitaya Fatiada Especial")
    end
  end

  test "a planilha importada na semana volta a pendente, para importar de novo" do
    travel_to Time.zone.local(2026, 10, 5, 9)
    import = ActsAsTenant.with_tenant(company) do
      record = OrderImports::Importer.new(company: company, customer: @hnorte, path: file_fixture("pedido_com_unidade.xlsx").to_s,
                                          filename: "pedido_com_unidade.xlsx").call
      assert OrderImports::Applier.new(import: record, mappings: {}).call.ok?
      record
    end

    delete order_clear_path(customer: "hnorte", week: WEEK)
    ActsAsTenant.with_tenant(company) do
      import.reload
      assert_equal "pending", import.status
      assert_nil import.payload["undo"]
    end
    assert_equal 0, lines(@hnorte)
  end

  test "pedido vazio avisa e não grava versão" do
    delete order_clear_path(customer: "hbp", week: Date.new(2027, 1, 4))
    follow_redirect!
    assert_match "O pedido desta semana já está vazio.", response.body
  end

  test "quem é da produção não apaga" do
    sign_in_as(user_for(:production))
    delete order_clear_path(customer: "hbp", week: WEEK)
    assert_operator lines(@hbp), :>, 0
  end
end
