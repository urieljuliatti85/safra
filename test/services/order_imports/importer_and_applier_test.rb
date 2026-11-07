require "test_helper"

class OrderImports::ImporterAndApplierTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @serra = Customer.find_by!(code: "hnorte")
    @hbp = Customer.find_by!(code: "hbp")
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def import(name, customer)
    OrderImports::Importer.new(company: company, customer: customer, path: file_fixture(name).to_s, filename: name).call
  end

  test "importar guarda as linhas, reconhece pelo apelido e calcula a semana" do
    record = import("pedido_com_unidade.xlsx", @serra)
    assert_equal Date.new(2026, 10, 12), record.week_start
    assert_equal "pending", record.status
    abobora = record.rows.find { |r| r["name"] == "ABÓBORA CUBOS" }
    assert_equal Product.find_by!(code: "abobora_cubos").id, abobora["product_id"]
    assert_equal "alias", abobora["matched_by"]
  end

  test "produto desconhecido fica sem produto e a prévia conta" do
    record = import("pedido_sem_unidade.xlsx", @hbp)
    pitaya = record.rows.find { |r| r["name"].start_with?("Pitaya") }
    assert_nil pitaya["product_id"]
    assert_equal 1, OrderImports::Preview.new(record).counts[:unmatched]
  end

  test "prévia compara com o pedido de hoje: igual, alterado, novo e removido" do
    product = Product.find_by!(code: "cenoura_ralada")
    order = Order.find_by!(customer: @serra, week_start: Date.new(2026, 10, 12))
    order.lines.find_by!(product: product, delivery_date: Date.new(2026, 10, 12)).update!(quantity: 9)  # arquivo traz 10: alterado
    order.lines.find_by!(product: product, delivery_date: Date.new(2026, 10, 13)).destroy!              # arquivo traz 3: novo
    order.lines.create!(product: product, unit: "kg", delivery_date: Date.new(2026, 10, 16), quantity: 4) # arquivo vazio: removido

    cells = OrderImports::Preview.new(import("pedido_com_unidade.xlsx", @serra)).lines
                                 .find { |l| l.row["name"] == "Cenoura Ralada" }.cells.index_by(&:date)
    assert_equal %i[changed new same same removed empty same],
                 (12..18).map { |day| cells[Date.new(2026, 10, day)].status }
    assert_equal 9, cells[Date.new(2026, 10, 12)].current
    assert_equal 10, cells[Date.new(2026, 10, 12)].new_quantity
  end

  test "aplicar grava o pedido, ignora linhas escolhidas e lembra o nome novo como apelido" do
    record = import("pedido_sem_unidade.xlsx", @hbp)
    pitaya_index = record.rows.index { |r| r["name"].start_with?("Pitaya") }
    produto = Product.find_by!(code: "abobora_lascas")
    result = OrderImports::Applier.new(import: record, mappings: { pitaya_index.to_s => produto.id.to_s }).call
    assert result.ok?, result.errors.inspect
    assert_equal "applied", record.reload.status
    order = Order.find_by!(customer: @hbp, week_start: Date.new(2026, 10, 12))
    assert_equal 3, order.lines.where(product: produto, delivery_date: Date.new(2026, 10, 13)).sum(:quantity)
    alias_record = CustomerAlias.find_by!(customer: @hbp, name_in_order: "Pitaya Fatiada Especial")
    assert_equal produto, alias_record.product
    # Da próxima vez o nome já é reconhecido.
    again = import("pedido_sem_unidade.xlsx", @hbp)
    assert_equal produto.id, again.rows.find { |r| r["name"].start_with?("Pitaya") }["product_id"]
  end

  test "sem escolher o produto de uma linha nova não aplica nada" do
    record = import("pedido_sem_unidade.xlsx", @hbp)
    before = OrderLine.count
    result = OrderImports::Applier.new(import: record, mappings: {}).call
    assert_not result.ok?
    assert_match "escolha o produto", result.errors.first
    assert_equal before, OrderLine.count
    assert_equal "pending", record.reload.status
  end

  test "ignorar a linha não grava nada para ela" do
    record = import("pedido_sem_unidade.xlsx", @hbp)
    pitaya_index = record.rows.index { |r| r["name"].start_with?("Pitaya") }
    result = OrderImports::Applier.new(import: record, mappings: { pitaya_index.to_s => "ignore" }).call
    assert result.ok?
    assert_not CustomerAlias.exists?(customer: @hbp, name_in_order: "Pitaya Fatiada Especial")
  end

  test "planilha com erro não aplica" do
    record = import("pedido_texto_invalido.xlsx", @serra)
    result = OrderImports::Applier.new(import: record, mappings: {}).call
    assert_not result.ok?
    assert_match "não é um número", result.errors.first
  end

  test "não aplica duas vezes" do
    record = import("pedido_com_unidade.xlsx", @serra)
    assert OrderImports::Applier.new(import: record, mappings: {}).call.ok?
    assert_not OrderImports::Applier.new(import: record.reload, mappings: {}).call.ok?
  end

  def order_state(customer)
    Order.find_by!(customer: customer, week_start: Date.new(2026, 10, 12)).lines
         .pluck(:product_id, :unit, :delivery_date, :quantity).sort_by { |row| row.map(&:to_s) }
  end

  def apply_sr_with_pitaya
    record = import("pedido_sem_unidade.xlsx", @hbp)
    pitaya_index = record.rows.index { |r| r["name"].start_with?("Pitaya") }
    assert OrderImports::Applier.new(import: record, mappings: { pitaya_index.to_s => Product.find_by!(code: "abobora_lascas").id.to_s }).call.ok?
    record.reload
  end

  test "desfazer devolve o pedido, apaga o apelido criado e reabre a importação" do
    before = order_state(@hbp)
    record = apply_sr_with_pitaya
    assert_not_equal before, order_state(@hbp)

    undoer = OrderImports::Undoer.new(import: record)
    assert undoer.undoable?
    assert_empty undoer.later_edits
    assert undoer.call.ok?

    assert_equal before, order_state(@hbp)
    assert_not CustomerAlias.exists?(customer: @hbp, name_in_order: "Pitaya Fatiada Especial")
    record.reload
    assert_equal "pending", record.status
    assert_nil record.applied_at
    assert_nil record.payload["undo"]
    assert_not OrderImports::Undoer.new(import: record).call.ok?
    # Reaberta, pode ser aplicada de novo.
    assert OrderImports::Applier.new(import: record, mappings: { record.rows.index { |r| r["name"].start_with?("Pitaya") }.to_s => "ignore" }).call.ok?
  end

  test "desfazer volta o apelido que a importação trocou de produto" do
    record = import("pedido_com_unidade.xlsx", @serra)
    index = record.rows.index { |r| r["name"] == "ABÓBORA CUBOS" }
    outro = Product.find_by!(code: "abobora_lascas")
    assert OrderImports::Applier.new(import: record, mappings: { index.to_s => outro.id.to_s }).call.ok?
    assert_equal outro, CustomerAlias.find_by!(customer: @serra, name_in_order: "ABÓBORA CUBOS").product

    assert OrderImports::Undoer.new(import: record.reload).call.ok?
    assert_equal Product.find_by!(code: "abobora_cubos"), CustomerAlias.find_by!(customer: @serra, name_in_order: "ABÓBORA CUBOS").product
  end

  test "desfazer avisa e passa por cima do que foi alterado no pedido depois da importação" do
    before = order_state(@hbp)
    record = apply_sr_with_pitaya
    line = Order.find_by!(customer: @hbp, week_start: Date.new(2026, 10, 12)).lines
                .find_by!(product: Product.find_by!(code: "abobora_lascas"), delivery_date: Date.new(2026, 10, 13))
    line.update!(quantity: 8)

    edits = OrderImports::Undoer.new(import: record).later_edits
    assert_equal 1, edits.size
    assert_equal [ Date.new(2026, 10, 13), 3, 8 ], [ edits.first.date, edits.first.imported, edits.first.current ]

    assert OrderImports::Undoer.new(import: record).call.ok?
    assert_equal before, order_state(@hbp)
  end

  test "simular o desfazer lista os planos enviados que vão mudar sem gravar nada" do
    # Cenoura ralada sai no dia da entrega: 15/10 cai na compra de 15/10.
    Order.find_by!(customer: @serra, week_start: Date.new(2026, 10, 12)).lines
         .find_by!(product: Product.find_by!(code: "cenoura_ralada"), delivery_date: Date.new(2026, 10, 15)).update!(quantity: 50)
    record = import("pedido_com_unidade.xlsx", @serra)
    assert OrderImports::Applier.new(import: record, mappings: {}).call.ok?
    (12..17).each do |day|
      PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: Date.new(2026, 10, day)).call)
    end
    PurchasePlanner.new(company: company).call.purchases.each do |date, needs|
      PlanPublisher.purchase(company: company, date: date, needs: needs)
    end
    after_apply = order_state(@serra)

    stale = OrderImports::Undoer.new(import: record).stale_after_undo
    assert_includes stale[:production], Date.new(2026, 10, 15)
    assert_includes stale[:purchase], Date.new(2026, 10, 15)
    assert_equal after_apply, order_state(@serra)
    assert_equal "applied", record.reload.status
  end

  # Pedido e apelidos voltam juntos: se o apelido falha depois de o pedido já ter voltado, nada fica pela metade.
  test "falha ao voltar o apelido desfaz também a volta do pedido" do
    record = import("pedido_com_unidade.xlsx", @serra)
    index = record.rows.index { |r| r["name"] == "ABÓBORA CUBOS" }
    assert OrderImports::Applier.new(import: record, mappings: { index.to_s => Product.find_by!(code: "abobora_lascas").id.to_s }).call.ok?
    order = Order.find_by!(customer: @serra, week_start: Date.new(2026, 10, 12))
    after_apply = [ order_state(@serra), order.versions.count ]

    CustomerAlias.define_singleton_method(:find_by) { |*| raise ActiveRecord::ActiveRecordError, "falha simulada no apelido" }
    begin
      assert_raises(ActiveRecord::ActiveRecordError) { OrderImports::Undoer.new(import: record.reload).call }
    ensure
      CustomerAlias.singleton_class.remove_method(:find_by)
    end

    assert_equal after_apply, [ order_state(@serra), order.versions.count ]
    assert_equal "applied", record.reload.status
    assert record.payload["undo"].present?
    assert OrderImports::Undoer.new(import: record).call.ok?, "depois da falha, desfazer de novo funciona"
  end

  # Sexta a terça: a semana é a de 12/10, que vai até 18/10 (R1.6). A terça 20/10 ficaria fora de qualquer grade.
  test "planilha que passa de uma semana avisa na conferência e não aplica" do
    before = order_state(@serra)
    record = import("pedido_sexta_a_terca.csv", @serra)

    assert_equal Date.new(2026, 10, 12), record.week_start
    assert_equal [ "A planilha vai de 16/10 a 20/10, mais do que uma semana (12/10 a 18/10). Separe em uma planilha por semana." ],
                 record.errors_list
    assert_not OrderImports::Applier.new(import: record, mappings: {}).call.ok?
    assert_equal before, order_state(@serra)
  end

  # A semana do pedido vai de segunda a domingo (R1.6, D6): a segunda seguinte já é de outra semana.
  test "planilha que termina na segunda seguinte passa de uma semana e não aplica" do
    record = import("pedido_segunda_a_segunda.csv", @serra)

    assert_match "mais do que uma semana (12/10 a 18/10)", record.errors_list.join
    assert_not OrderImports::Applier.new(import: record, mappings: {}).call.ok?
  end

  test "importação aplicada antes do desfazer existir não pode ser desfeita" do
    record = apply_sr_with_pitaya
    record.update!(payload: record.payload.except("undo"))
    assert_not OrderImports::Undoer.new(import: record).undoable?
    assert_not OrderImports::Undoer.new(import: record).call.ok?
  end

  test "aviso quando o título parece de outro cliente" do
    record = import("pedido_com_unidade.xlsx", @hbp)
    assert_match "parece ser de Hospital Horizonte Norte", record.payload["customer_warning"]
  end

  test "planilhas reais dos clientes reproduzem os pedidos já carregados nos seeds" do
    dir = Rails.root.join("referencia/planilhas")
    skip "referencia/planilhas não está no repositório" unless dir.directory?

    {
      "hbp" => %w[12-10-26_PEDIDO_HOSPITAL_ST_RITA_PROCESSADOS.ods 12-10-26_HOSPITAL_ST_RITA_PEDIDOS_IN_NATURA.xls],
      "hnorte" => %w[12-10-26_PEDIDO_H_HORIZONTE_SERRA_PROCESSADOS.xlsx 12-10-26_PEDIDO_H_HORIZONTE_SERRA_IN_NATURA.xlsx],
      "hsul" => %w[12-10-26_PEDIDO_H_HORIZONTE_VITORIA_PROCESSADOS.xlsx]
    }.each do |code, names|
      names.each do |name|
        path = dir.join(name)
        next unless path.exist?

        record = OrderImports::Importer.new(company: company, customer: Customer.find_by!(code: code), path: path.to_s, filename: name).call
        counts = OrderImports::Preview.new(record).counts
        assert_equal({ new: 0, changed: 0, removed: 0, unmatched: 0 }, counts, name)
        assert_empty record.errors_list, name
      end
    end
  end
end
