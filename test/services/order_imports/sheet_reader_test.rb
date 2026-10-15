require "test_helper"

class OrderImports::SheetReaderTest < ActiveSupport::TestCase
  def read(name)
    OrderImports::SheetReader.new(file_fixture(name).to_s, extension: ".xlsx").call
  end

  test "acha as datas, a coluna do nome e a da unidade" do
    result = read("pedido_com_unidade.xlsx")
    assert_equal (Date.new(2026, 10, 12)..Date.new(2026, 10, 18)).to_a, result.dates
    assert_equal "HOSPITAL HORIZONTE NORTE", result.title
    abobora = result.rows.find { |r| r.name == "ABÓBORA CUBOS" }
    assert_equal "kg", abobora.unit
    assert_equal({ Date.new(2026, 10, 14) => 2, Date.new(2026, 10, 17) => 18 }, abobora.quantities.compact)
  end

  test "ignora a coluna de total, linhas de seção, totais e linhas sem quantidade" do
    result = read("pedido_com_unidade.xlsx")
    assert_equal %w[ABÓBORA\ CUBOS Cenoura\ Ralada BATATA\ CUBINHOS ALECRIM], result.rows.map(&:name)
    assert_equal 1, result.ignored_blank
  end

  test "texto numérico e soma viram número com aviso" do
    result = read("pedido_com_unidade.xlsx")
    batata = result.rows.find { |r| r.name == "BATATA CUBINHOS" }
    assert_equal 7, batata.quantities[Date.new(2026, 10, 15)]
    assert_match "somado como 7", batata.warnings.join
    alecrim = result.rows.find { |r| r.name == "ALECRIM" }
    assert_equal BigDecimal("0.2"), alecrim.quantities[Date.new(2026, 10, 12)]
    assert_match "veio como texto", alecrim.warnings.join
  end

  test "sem coluna de unidade a unidade fica em branco para usar a do produto" do
    result = read("pedido_sem_unidade.xlsx")
    assert_nil result.rows.first.unit
    assert_equal 112, result.rows.first.quantities[Date.new(2026, 10, 18)]
  end

  test "com várias abas usa a que tem mais produtos com quantidade" do
    result = read("pedido_duas_abas.xlsx")
    assert_equal "Planilha2", result.sheet
    assert_equal %w[ABACAXI], result.rows.map(&:name)
  end

  test "texto que não é número vira erro e não entra" do
    result = read("pedido_texto_invalido.xlsx")
    assert_equal 1, result.errors.size
    assert_match "\"duas caixas\" não é um número", result.errors.first
  end

  test "arquivo sem datas é recusado com mensagem" do
    Tempfile.create([ "vazio", ".csv" ]) do |file|
      file.write("produto,quantidade\nabobora,3\n")
      file.flush
      error = assert_raises(OrderImports::SheetReader::Unreadable) { OrderImports::SheetReader.new(file.path, extension: ".csv").call }
      assert_match "datas da semana", error.message
    end
  end
end
