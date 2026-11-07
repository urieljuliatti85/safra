require "test_helper"

class OrderVersionsTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @customer = Customer.find_by!(code: "hbp")
    @order = Order.find_by!(customer: @customer, week_start: Date.new(2026, 10, 12))
    @product = Product.find_by!(code: "cenoura_cubinhos")
    @key = "#{@product.id}|kg"
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def state
    @order.lines.reload.group(:product_id, :unit, :delivery_date).sum(:quantity).select { |_, q| q.positive? }
  end

  def save(cells, **options)
    OrderGridSaver.new(order: @order, quantities: { @key => cells }, **options).call
  end

  test "o primeiro salvamento guarda como o pedido estava e a versão com o que mudou" do
    before = state
    current = before.fetch([ @product.id, "kg", Date.new(2026, 10, 12) ])
    sunday = before[[ @product.id, "kg", Date.new(2026, 10, 18) ]]
    assert save({ "2026-10-12" => "11,5", "2026-10-18" => "3" }).ok?

    initial, first = @order.versions.order(:version).to_a
    assert_equal [ 1, "initial", nil ], [ initial.version, initial.source, initial.user_name ]
    assert_equal before, initial.quantities
    assert_equal [ 2, "grid" ], [ first.version, first.source ]
    assert_equal state, first.quantities
    assert_equal [ [ "2026-10-12", current.to_s("F").sub(/\.0\z/, ""), "11.5" ], [ "2026-10-18", sunday&.to_s("F")&.sub(/\.0\z/, ""), "3" ] ],
                 first.changes_list.map { |c| [ c["date"], c["before"], c["after"] ] }
    assert_equal @product.name, first.changes_list.first["product"]
  end

  test "salvar sem mudar nada não cria versão" do
    current = state.fetch([ @product.id, "kg", Date.new(2026, 10, 12) ])
    assert save({ "2026-10-12" => current.to_s("F") }).ok?
    assert_equal 0, @order.versions.count
  end

  test "pedido vazio começa direto na versão do salvamento" do
    order = Order.create!(customer: @customer, week_start: Date.new(2026, 11, 2))
    OrderGridSaver.new(order: order, quantities: { @key => { "2026-11-03" => "4" } }).call
    assert_equal [ [ 1, "grid" ] ], order.versions.pluck(:version, :source)
  end

  test "restaurar volta o pedido ao retrato e grava uma versão nova" do
    original = state
    save({ "2026-10-12" => "", "2026-10-18" => "3" })
    save({ "2026-10-17" => "8,125" })
    assert_equal 3, @order.versions.count

    initial = @order.versions.find_by!(version: 1)
    result = OrderVersionRestorer.new(version: initial).call
    assert result.ok?, result.errors.inspect
    assert_equal original, state
    restored = @order.versions.newest_first.first
    assert_equal [ 4, "restore", 1 ], [ restored.version, restored.source, restored.restored_from_version ]
    assert_equal "Versão restaurada (v1)", restored.source_label
    assert_equal 4, @order.versions.count # nada foi apagado

    assert_not OrderVersionRestorer.new(version: restored).call.ok?
  end

  # A grade da semana de 12/10 vai até 18/10 (R1.6): dia depois disso não apareceria em grade nenhuma, mas entraria no cálculo.
  test "quantidade fora da semana do pedido é recusada e nada é gravado" do
    before = state
    result = save({ "2026-10-13" => "5", "2026-10-20" => "3" })

    assert_not result.ok?
    assert_equal [ "#{@product.name} em 20/10: fora da semana do pedido (12/10 a 18/10)." ], result.errors
    assert_equal before, state
    assert_equal 0, @order.versions.count
  end

  # Linha gravada antes da regra existir entra no retrato de toda versão: restaurar reenvia ela igual e precisa passar.
  test "linha antiga fora da semana não impede restaurar, mas não pode mudar de quantidade" do
    @order.lines.create!(product: @product, unit: "kg", delivery_date: Date.new(2026, 10, 20), quantity: 3)
    original = state
    assert save({ "2026-10-13" => "7,25" }).ok?

    result = OrderVersionRestorer.new(version: @order.versions.find_by!(version: 1)).call
    assert result.ok?, result.errors.inspect
    assert_equal original, state

    changed = save({ "2026-10-20" => "4" })
    assert_equal [ "#{@product.name} em 20/10: fora da semana do pedido (12/10 a 18/10)." ], changed.errors
    assert_equal original, state
  end

  # A semana do pedido vai de segunda a domingo (R1.6, D6), nos dois limites.
  test "limites da semana: o domingo vale, a segunda seguinte e o domingo anterior não" do
    assert save({ "2026-10-18" => "2,5" }).ok?
    assert_equal BigDecimal("2.5"), state[[ @product.id, "kg", Date.new(2026, 10, 18) ]]

    assert_equal [ "#{@product.name} em 19/10: fora da semana do pedido (12/10 a 18/10)." ], save({ "2026-10-19" => "4" }).errors

    result = save({ "2026-10-11" => "4" })
    assert_equal [ "#{@product.name} em 11/10: fora da semana do pedido (12/10 a 18/10)." ], result.errors
    assert_nil state[[ @product.id, "kg", Date.new(2026, 10, 11) ]]
  end

  test "zero fora da semana apaga a linha que já estava lá" do
    @order.lines.create!(product: @product, unit: "kg", delivery_date: Date.new(2026, 10, 20), quantity: 3)

    assert save({ "2026-10-20" => "" }).ok?
    assert_not @order.lines.exists?(delivery_date: Date.new(2026, 10, 20))
  end

  test "importar e desfazer viram versões ligadas à planilha" do
    record = OrderImports::Importer.new(company: company, customer: @customer, path: file_fixture("pedido_sem_unidade.xlsx").to_s,
                                        filename: "pedido_sem_unidade.xlsx").call
    pitaya = record.rows.index { |r| r["name"].start_with?("Pitaya") }
    assert OrderImports::Applier.new(import: record, mappings: { pitaya.to_s => Product.find_by!(code: "abobora_lascas").id.to_s }).call.ok?
    import_version = @order.versions.newest_first.first
    assert_equal [ "import", record ], [ import_version.source, import_version.order_import ]

    assert OrderImports::Undoer.new(import: record.reload).call.ok?
    undo_version = @order.versions.newest_first.first
    assert_equal [ "undo", record ], [ undo_version.source, undo_version.order_import ]
    assert_equal @order.versions.find_by!(source: "initial").quantities, undo_version.quantities
  end
end
