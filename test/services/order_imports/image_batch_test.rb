require "test_helper"

class OrderImports::ImageBatchTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @fallback = Customer.find_by!(code: "hbp")
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def batch(name, **options)
    OrderImports::ImageBatch.new(company: company, customer: @fallback, path: file_fixture(name).to_s, filename: name, **options).call
  end

  test "cada imagem do ODT vira um pedido em imagem com o cliente do texto" do
    imports = batch("pedidos_documento.odt")
    assert_equal %w[amoll ahotel], imports.map { |i| i.customer.code }
    assert_equal [ Date.new(2026, 10, 12), Date.new(2026, 10, 12) ], imports.map(&:week_start)
    assert imports.all? { |i| i.kind == "image" && i.image.attached? }
    assert_equal 1, imports.map { |i| i.payload["batch"] }.uniq.size
    assert_equal [ 1, 2 ], imports.map { |i| i.payload["position"] }
    assert_equal imports, imports.first.siblings.to_a
  end

  test "sem texto de pedido usa o cliente escolhido e a data informada" do
    import = batch("documento_sem_titulos.odt", date: Date.new(2026, 10, 21)).first
    assert_equal @fallback, import.customer
    assert_equal Date.new(2026, 10, 19), import.week_start
    assert_equal "Imagem 1", import.payload["label"]
  end

  test "imagem avulsa vira um pedido em imagem" do
    import = batch("imagem_pedido.png", content_type: "image/png").first
    assert import.image.attached?
    assert_equal "image/png", import.image.blob.content_type
    assert_equal @fallback, import.customer
  end

  test "tipo de arquivo não aceito é recusado" do
    error = assert_raises(OrderImports::OdtReader::Unreadable) { batch("pedido_com_unidade.xlsx", content_type: "application/zip") }
    assert_match "Formato não aceito", error.message
  end
end
