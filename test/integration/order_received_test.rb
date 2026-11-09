require "test_helper"

class OrderReceivedTest < ActionDispatch::IntegrationTest
  test "quem lança informa quando o pedido chegou e a tela mostra se foi depois do prazo" do
    sign_in_as(user_for(:office))
    patch order_received_path(customer: "hbp", week: "2026-10-12"), params: { received_at: "2026-10-09T16:20" }

    assert_redirected_to orders_path(customer: "hbp", week: Date.new(2026, 10, 12))
    follow_redirect!
    assert_match "Pedido recebido em 09/10 às 16:20.", response.body
    assert_select "strong", "Depois do prazo (Qui 08/10, 15h)"
  end

  test "data vazia não grava" do
    sign_in_as(user_for(:office))
    patch order_received_path(customer: "hbp", week: "2026-10-12"), params: { received_at: "" }
    follow_redirect!
    assert_match "Informe a data e a hora em que o pedido chegou.", response.body
  end

  test "a produção não altera a chegada do pedido" do
    ActsAsTenant.with_tenant(company) { Order.joins(:customer).find_by!(customers: { code: "hbp" }, week_start: "2026-10-12").update!(received_at: nil) }
    sign_in_as(user_for(:production))
    patch order_received_path(customer: "hbp", week: "2026-10-12"), params: { received_at: "2026-10-09T16:20" }
    received = ActsAsTenant.with_tenant(company) { Order.joins(:customer).find_by!(customers: { code: "hbp" }, week_start: "2026-10-12").received_at }
    assert_not_equal Time.zone.local(2026, 10, 9, 16, 20), received
  end

  test "a grade mostra e salva a medida pedida de cada linha (R1.14, D12)" do
    sign_in_as(user_for(:office))
    product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "cenoura_cubinhos") }
    patch orders_path(customer: "hbp", week: "2026-10-12"), params: { entry_type: "alteration", measures: { "#{product.id}|kg" => "8 × 8 mm" } }
    follow_redirect!
    assert_match "Medida salva. As quantidades não mudaram", response.body
    assert_select "input[name='measures[#{product.id}|kg]'][value='8 × 8 mm']"
  end
end
