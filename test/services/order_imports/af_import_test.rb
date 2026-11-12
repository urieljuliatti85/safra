require "test_helper"
require "prawn"

# PDF de AFs da Nutrir (D2, D3, D4). As linhas imitam o formato do PDF de AFs (números, datas e preços inventados) e a AF
# alterada 0009100649 (entrega 06/11/2026, vagem cubinho de 95 para 120 kg).
class OrderImports::AfImportTest < ActiveSupport::TestCase
  setup do
    # Antes das 48 h da entrega (R1.26, D8): estes testes não são sobre o prazo de alteração.
    travel_to Time.zone.local(2026, 10, 28, 9)
    ActsAsTenant.current_tenant = company
    @nutrir = Customer.find_by!(code: "nutrir")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Dir.glob(Rails.root.join("tmp/af-*.pdf")).each { |file| File.delete(file) }
  end

  MONTH = [
    [ "Autorização de Fornecimento AF: 0009100648", "Filial Destino: USINA LITORAL Código: 4471", "DATA DE ENTREGA: 05/11/2026",
      "CENOURA PROCESSADA CUBO (20MM) KG 17,000 5,00000 PADRAO / 85,00", "LARANJA PERA DESCASCADA-UN 1.380,000 2,00000 PADRAO / 2.760,00",
      "Total: 2.845,00" ],
    [ "Autorização de Fornecimento AF: 0009100649", "Filial Destino: USINA LITORAL Código: 4471", "DATA DE ENTREGA: 06/11/2026",
      "VAGEM PROCESSADA CUBINHO KG 95,000 9,00000 PADRAO / 855,00", "BETERRABA PROCESSADA PALITO KG 300,000 4,00000 PADRAO / 1.200,00" ],
    [ "Autorização de Fornecimento AF: 0009100650", "Filial Destino: USINA LITORAL Código: 4471", "DATA DE ENTREGA: 09/11/2026",
      "BATATA PROCESSADA DESCASCADA INT KG 80,000 3,00000 PADRAO / 240,00" ]
  ].freeze
  ALTERATION = [ [ "Autorização de Fornecimento ALTERAÇÃO", "Unidade Destino: 4471 - USINA LITORAL", "Data de Entrega: 06/11/2026",
                   "Autorização de Fornecimento: 0009100649", "* VAGEM PROCESSADA CUBINHO KG - KG 120,000 9,00 PADRAO 1080,00" ] ].freeze

  def pdf(pages)
    path = Rails.root.join("tmp/af-#{SecureRandom.hex(4)}.pdf")
    Prawn::Document.generate(path) do |doc|
      pages.each_with_index do |lines, index|
        doc.start_new_page if index.positive?
        lines.each { |line| doc.text line }
      end
    end
    path.to_s
  end

  def self.pdf_file(pages) = new("pdf").pdf(pages)

  def import(pages, name)
    OrderImports::AfImporter.new(company: company, customer: @nutrir, path: pdf(pages), filename: name).call
  end

  def quantities(week) = Order.find_by!(customer: @nutrir, week_start: week).lines.reload.includes(:product)
                              .to_h { |l| [ [ l.product.code, l.delivery_date.day ], [ l.quantity.to_i, l.af_number ] ] }

  test "PDF de outra unidade é recusado quando o cadastro do cliente tem a unidade das AFs" do
    other_unit = MONTH.map { |page| page.map { |line| line.sub("Código: 4471", "Código: 9001") } }
    assert_equal [ "O PDF é da unidade 9001; o cadastro de Nutrir UL atende a 4471." ], import(other_unit, "outra.pdf").payload["errors"]

    @nutrir.update!(af_unit_code: nil)
    assert_empty import(other_unit, "outra.pdf").payload["errors"]
  end

  test "o PDF do mês vai para o pedido de cada semana, com o número da AF" do
    record = import(MONTH, "PEDIDOS NUTRIR NOVEMBRO 2026.pdf")
    assert_equal [ "0009100648", "0009100649", "0009100650" ], record.payload["afs"].map { |af| af["number"] }
    assert_empty record.payload["errors"]

    result = OrderImports::AfApplier.new(import: record).call
    assert result.ok?, result.errors.inspect
    assert_equal [ Date.new(2026, 11, 2), Date.new(2026, 11, 9) ], result.weeks
    assert_equal({ [ "cenoura_cubos", 5 ] => [ 17, "0009100648" ], [ "laranja_desc", 5 ] => [ 1380, "0009100648" ],
                   [ "vagem_cubinhos", 6 ] => [ 95, "0009100649" ], [ "beterraba_palitos", 6 ] => [ 300, "0009100649" ] },
                 quantities(Date.new(2026, 11, 2)))
    assert_equal({ [ "batata_inteira", 9 ] => [ 80, "0009100650" ] }, quantities(Date.new(2026, 11, 9)))
  end

  test "a AF alterada troca só aquela AF: vagem de 95 para 120 kg, beterraba sai, o resto da semana fica" do
    OrderImports::AfApplier.new(import: import(MONTH, "mes.pdf")).call
    record = import(ALTERATION, "PDF de pedido de alteração da Nutrir Usina (UL).pdf")
    af = record.payload["afs"].sole
    assert_equal [ "0009100649", "2026-11-06", true ], af.values_at("number", "date", "alteration")
    assert af["items"].sole["changed"]

    assert OrderImports::AfApplier.new(import: record).call.ok?
    assert_equal({ [ "cenoura_cubos", 5 ] => [ 17, "0009100648" ], [ "laranja_desc", 5 ] => [ 1380, "0009100648" ],
                   [ "vagem_cubinhos", 6 ] => [ 120, "0009100649" ] }, quantities(Date.new(2026, 11, 2)))
  end

  test "a caixa das 48 h só vale para AF que muda quantidade já pedida a menos de 48 h da entrega" do
    month = import(MONTH, "mes.pdf")
    travel_to(Time.zone.local(2026, 11, 5, 10)) { assert_empty OrderImports::AfApplier.new(import: month).late_alterations }
    OrderImports::AfApplier.new(import: month).call

    alteration = import(ALTERATION, "alteracao.pdf")
    again = import(MONTH, "mes de novo.pdf")
    travel_to Time.zone.local(2026, 11, 5, 10) do
      late = OrderImports::AfApplier.new(import: alteration).late_alterations
      assert_equal 2, late.size # vagem muda, beterraba sai
      assert late.all? { |label| label.start_with?("AF 0009100649: ") && label.end_with?(" em 06/11") }, late.inspect
      assert_empty OrderImports::AfApplier.new(import: again).late_alterations # mesmas quantidades
    end
  end

  test "nome sem produto não grava nada" do
    record = import([ MONTH.first + [ "PEPINO JAPONES PROCESSADO KG 5,000 3,00000 PADRAO / 15,00" ] ], "novo.pdf")
    result = OrderImports::AfApplier.new(import: record).call
    assert_equal [ "\"PEPINO JAPONES PROCESSADO\" não tem produto: cadastre o apelido e importe de novo." ], result.errors
    assert_nil Order.find_by(customer: @nutrir, week_start: Date.new(2026, 11, 2))&.lines&.where(af_number: "0009100648")&.first
  end
end
