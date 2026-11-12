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

  # XXE: entidade externa no content.xml não pode trazer arquivo do servidor para o texto do documento.
  test "entidade externa no documento não lê arquivo do servidor" do
    secret = Rails.root.join("tmp/segredo-#{SecureRandom.hex(4)}.txt")
    File.write(secret, "PEDIDO SEGREDO 13/10/26")
    path = odt_copy do |xml|
      xml.sub(/<office:document-content/, %(<!DOCTYPE office:document-content [<!ENTITY x SYSTEM "file://#{secret}">]>\n<office:document-content))
         .sub("PEDIDO MOLLINARI SEGUNDA FEIRA 12/10/26", "&x;")
    end

    entries = OrderImports::OdtReader.new(path).call
    assert entries.none? { |e| e.hint.to_s.include?("SEGREDO") || e.customer_word.to_s.include?("SEGREDO") }
  ensure
    FileUtils.rm_f(secret) if secret
  end

  test "content.xml grande demais é recusado sem ler tudo" do
    path = odt_copy { |xml| xml.sub("</office:document-content>", "<!-- #{'a' * (OrderImports::OdtReader::MAX_CONTENT_BYTES + 1)} --></office:document-content>") }
    error = assert_raises(OrderImports::OdtReader::Unreadable) { OrderImports::OdtReader.new(path).call }
    assert_match "grande demais", error.message
  end

  test "documento sem imagens é recusado com mensagem" do
    error = assert_raises(OrderImports::OdtReader::Unreadable) { OrderImports::OdtReader.new(file_fixture("documento_sem_imagens.odt").to_s).call }
    assert_match "Não achei imagens", error.message
  end

  test "arquivo que não é ODT é recusado" do
    error = assert_raises(OrderImports::OdtReader::Unreadable) { OrderImports::OdtReader.new(file_fixture("pedido_com_unidade.xlsx").to_s).call }
    assert_match "ODT", error.message
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

    entries = travel_to(Time.zone.local(2026, 10, 24, 9)) { OrderImports::OdtReader.new(path, prefixes: [ "Aurora" ]).call }
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

  teardown { @odt_paths&.each { |path| FileUtils.rm_f(path) } }

  private

  # Cópia do documento de exemplo com o content.xml trocado pelo bloco.
  def odt_copy
    path = Rails.root.join("tmp/odt-#{SecureRandom.hex(4)}.odt").to_s
    (@odt_paths ||= []) << path
    FileUtils.cp(file_fixture("pedidos_documento.odt").to_s, path)
    Zip::File.open(path) do |zip|
      xml = yield zip.read("content.xml").force_encoding("UTF-8")
      zip.get_output_stream("content.xml") { |io| io.write(xml) }
    end
    path
  end
end
