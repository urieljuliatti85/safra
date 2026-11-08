require "test_helper"

class OrderImports::OdtReaderTest < ActiveSupport::TestCase
  test "lê as imagens na ordem do documento com cliente e dia do texto" do
    entries = OrderImports::OdtReader.new(file_fixture("pedidos_documento.odt").to_s).call
    assert_equal %w[a.png b.png], entries.map(&:filename)
    assert_equal %w[MOLLINARI HOTEL], entries.map(&:customer_word)
    assert_equal [ Date.new(2026, 10, 12), Date.new(2026, 10, 13) ], entries.map(&:date_hint)
    assert_equal "PEDIDO MOLLINARI SEGUNDA FEIRA 12/10/26", entries.first.hint
    assert entries.all? { |e| e.data.start_with?("\x89PNG".b) }
  end

  test "sem títulos de pedido as imagens vêm sem pista" do
    entries = OrderImports::OdtReader.new(file_fixture("documento_sem_titulos.odt").to_s).call
    assert_equal 1, entries.size
    assert_nil entries.first.hint
    assert_nil entries.first.date_hint
  end

  test "documento sem imagens é recusado com mensagem" do
    error = assert_raises(OrderImports::OdtReader::Unreadable) { OrderImports::OdtReader.new(file_fixture("documento_sem_imagens.odt").to_s).call }
    assert_match "Não achei imagens", error.message
  end

  test "arquivo que não é ODT é recusado" do
    error = assert_raises(OrderImports::OdtReader::Unreadable) { OrderImports::OdtReader.new(file_fixture("pedido_com_unidade.xlsx").to_s).call }
    assert_match "ODT", error.message
  end

  test "documento real da Aurora traz quatro imagens com cliente e dia" do
    path = Rails.root.join("referencia/planilhas/12-10-26_PEDIDOS_AURORA.odt")
    skip "referencia/planilhas não está no repositório" unless path.exist?

    entries = OrderImports::OdtReader.new(path.to_s).call
    assert_equal %w[MOLLINARI HOTEL FÁBRICA FÁBRICA], entries.map(&:customer_word)
    assert_equal [ [ 10, 12 ], [ 10, 13 ], [ 10, 13 ], [ 10, 15 ] ], entries.map { |e| [ e.date_hint.month, e.date_hint.day ] }
  end

  # D19: desde 26/10/2026 a Aurora escreve "AURORA HOTEL SEGUNDA 26/10", sem "PEDIDO" e sem o ano.
  test "título novo da Aurora, sem PEDIDO e sem ano, também dá cliente e dia" do
    ActsAsTenant.current_tenant = company
    source = file_fixture("pedidos_documento.odt").to_s
    path = Rails.root.join("tmp/aurora-#{SecureRandom.hex(4)}.odt").to_s
    FileUtils.cp(source, path)
    Zip::File.open(path) do |zip|
      xml = zip.read("content.xml").sub("PEDIDO MOLLINARI SEGUNDA FEIRA 12/10/26", "AURORA MOLLINARI SEGUNDA 26/10")
                                   .sub(%r{PEDIDO HOTEL [^<]*?\d{2}/\d{2}/\d{2}}, "AURORA HOTEL TERÇA 27/10")
      zip.get_output_stream("content.xml") { |io| io.write(xml) }
    end

    entries = travel_to(Time.zone.local(2026, 10, 24, 9)) { OrderImports::OdtReader.new(path).call }
    assert_equal %w[MOLLINARI HOTEL], entries.map(&:customer_word)
    assert_equal [ Date.new(2026, 10, 26), Date.new(2026, 10, 27) ], entries.map(&:date_hint)
    assert_equal "AURORA MOLLINARI SEGUNDA 26/10", entries.first.hint

    # "MOLINARI", com um L, ainda é a Aurora Mollinari.
    Zip::File.open(path) do |zip|
      xml = zip.read("content.xml").sub("AURORA MOLLINARI", "AURORA MOLINARI")
      zip.get_output_stream("content.xml") { |io| io.write(xml) }
    end
    imports = travel_to(Time.zone.local(2026, 10, 24, 9)) do
      OrderImports::ImageBatch.new(company: company, customer: Customer.find_by!(code: "hbp"), path: path, filename: "aurora.odt",
                                   content_type: "application/vnd.oasis.opendocument.text", date: nil).call
    end
    assert_equal %w[amoll ahotel], imports.map { |i| i.customer.code }
  ensure
    ActsAsTenant.current_tenant = nil
    FileUtils.rm_f(path) if path
  end
end
