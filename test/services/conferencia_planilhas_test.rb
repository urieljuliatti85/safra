require "test_helper"

# Compara os planners com as planilhas de 13 e 15/10 (referencia_planilhas.yml, carregado pelo seed). Diferenças são listadas, não falham:
# cada uma é uma regra ainda não cadastrada ou um ajuste manual (docs/duvidas.md).
class ConferenciaPlanilhasTest < ActiveSupport::TestCase
  setup do
    @conferencia = SheetComparison.new(company)
  end

  test "seeds carregam cadastros e pedidos da semana" do
    ActsAsTenant.with_tenant(company) do
      assert_equal 116, Product.count
      assert_equal 7, Customer.count
      # R1.2 (D1): a Nutrir é um cliente só, com a unidade Usina Litoral (4471).
      assert_equal "Nutrir · Usina Litoral", Customer.find_by!(code: "nutrir").name
      # R1.15 e R1.17 (D13, D14): CHUCHU LÂMINAS, do pedido do Horizonte Norte, agora tem produto e corte.
      assert_equal %w[chuchu laminas], Product.find_by!(code: "chuchu_laminas").then { |p| [ p.raw_material.code, p.cut.code ] }
      assert_equal %w[cubos_g gomos laminas meia_lua], Cut.where(code: %w[laminas meia_lua gomos cubos_g]).order(:code).pluck(:code)
      # R1.18 (D16, D17): a abóbora japonesa da Nutrir tem matéria-prima própria; a banana dos cortes é a banana-da-terra.
      assert_equal "abobora_japonesa", Product.find_by!(code: "abobora_japonesa_cubos").raw_material.code
      assert_equal %w[banana_terra], Product.where(code: %w[banana_cubinhos banana_rodelas banana_gomos]).map { |p| p.raw_material.code }.uniq
      assert_nil RawMaterial.find_by(code: "banana")
      # R1.6 (D6): a semana do pedido vai de segunda a domingo; a entrega de 19/10 da Aurora Mollinari fica no pedido de 19/10.
      assert Order.where(week_start: "2026-10-12").all? { |order| order.lines.all? { |line| order.week_dates.cover?(line.delivery_date) } }
      assert_equal 5, Order.joins(:customer).find_by!(customers: { code: "amoll" }, week_start: "2026-10-19").lines.count
      assert_equal 375, OrderLine.count
      assert_equal 3, PurchaseDay.count
      assert_equal 0, Product.where(product_group: "processed", cut_id: nil).count
    end
  end

  test "seeds são idempotentes" do
    load_seeds
    ActsAsTenant.with_tenant(company) do
      assert_equal 1, Company.count
      assert_equal 116, Product.count
      assert_equal 375, OrderLine.count
    end
  end

  test "ralados, picados e rodelas batem 100% com a planilha (regra confirmada)" do
    rows = @conferencia.confirmed_same_day_rows
    assert_not_empty rows
    diferentes = rows.reject(&:ok?)
    assert_empty diferentes.map { |row| [ row.date, row.code, row.planilha, row.sistema ] }
  end

  test "lista as diferenças com as planilhas sem falhar" do
    report = @conferencia.report
    File.write(Rails.root.join("tmp/conferencia_planilhas.txt"), "#{report}\n\nResumo: #{@conferencia.summary}\n")
    # Só imprime com VERBOSE_CONFERENCIA=1, para não poluir a saída do pre-commit e do CI.
    puts "\n#{report}\n\nResumo: #{@conferencia.summary}" if ENV["VERBOSE_CONFERENCIA"]
    assert_not_empty @conferencia.production_rows
    assert_not_empty @conferencia.purchase_rows
  end
end
