require "test_helper"

# Compara os planners com as planilhas de 13 e 15/10 (referencia_planilhas.yml, carregado pelo seed). Diferenças são listadas, não falham:
# cada uma é uma regra ainda não cadastrada ou um ajuste manual (docs/duvidas.md).
class ConferenciaPlanilhasTest < ActiveSupport::TestCase
  setup do
    @conferencia = SheetComparison.new(company)
  end

  test "seeds carregam cadastros e pedidos da semana" do
    ActsAsTenant.with_tenant(company) do
      assert_equal 95, Product.count
      assert_equal 7, Customer.count
      # R1.2 (D1): a Nutrir é um cliente só, com a unidade Usina Litoral (4471).
      assert_equal "Nutrir · Usina Litoral", Customer.find_by!(code: "nutrir").name
      assert_equal 375, OrderLine.count
      assert_equal 3, PurchaseDay.count
      assert_equal 0, Product.where(product_group: "processed", cut_id: nil).count
    end
  end

  test "seeds são idempotentes" do
    load_seeds
    ActsAsTenant.with_tenant(company) do
      assert_equal 1, Company.count
      assert_equal 95, Product.count
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
