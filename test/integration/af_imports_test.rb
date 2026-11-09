require "test_helper"
require_relative "../services/order_imports/af_import_test"

class AfImportsTest < ActionDispatch::IntegrationTest
  teardown { Dir.glob(Rails.root.join("tmp/af-*.pdf")).each { |file| File.delete(file) } }

  test "enviar o PDF de AFs, conferir e aplicar nos pedidos das semanas" do
    sign_in_as(user_for(:office))
    path = OrderImports::AfImportTest.pdf_file(OrderImports::AfImportTest::MONTH)
    post order_imports_path, params: { entry_type: "new", customer: "nutrir", file: Rack::Test::UploadedFile.new(path, "application/pdf", original_filename: "PEDIDOS NUTRIR NOVEMBRO 2026.pdf") }
    follow_redirect!
    assert_select "h1", "Conferir AFs"
    assert_match "3 AFs, de 05/11 a 09/11", response.body
    assert_match "Vagem em cubinhos", response.body

    import = ActsAsTenant.with_tenant(company) { OrderImport.where(kind: "af").order(:id).last }
    post apply_order_import_path(import)
    assert_redirected_to orders_path(customer: "nutrir", week: Date.new(2026, 11, 2))
    follow_redirect!
    assert_match "AFs de Nutrir UL aplicadas nos pedidos das semanas de 02/11 e 09/11.", response.body
  end
end
