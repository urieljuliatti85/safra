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
