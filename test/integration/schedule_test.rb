require "test_helper"

# Programação em quatro dias com a marca de andamento (R3.3, R3.4, D35).
class ScheduleTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(user_for(:office)) }

  def line_on(date, customer_code = "hbp")
    ActsAsTenant.with_tenant(company) do
      OrderLine.joins(order: :customer).where(customers: { code: customer_code }, delivery_date: date).where("quantity > 0").order(:id).first
    end
  end

  test "mostra quatro dias de entrega a partir da data, atravessando a semana" do
    get schedule_path(date: "2026-10-17")
    assert_response :success
    assert_select ".page-sub", /Sáb 17\/10 a Ter 20\/10 \(quatro dias\)/
  end

  test "cada item mostra a quantidade total e começa com o quadrado: produzir no dia" do
    line = line_on(Date.new(2026, 10, 14))
    get schedule_path(date: "2026-10-13")
    assert_select "tr#linha-#{line.id}" do
      assert_select "td", "Qua 14/10"
      assert_select "button[aria-pressed=false]", /□ produzir no dia/
      assert_select "td.qty", Formatting.qty(line.quantity)
    end
  end

  test "o Gerente marca o item como já pronto (ponto) e volta para o quadrado, sem mudar a quantidade" do
    line = line_on(Date.new(2026, 10, 14))
    quantity = line.quantity
    patch schedule_mark_path(line, date: "2026-10-13", mark: "ready")
    assert_redirected_to schedule_path(date: "2026-10-13", anchor: "linha-#{line.id}")
    assert_equal "ready", line.reload.schedule_mark
    assert_equal quantity, line.quantity

    get schedule_path(date: "2026-10-13")
    assert_select "tr#linha-#{line.id} button[aria-pressed=true]", /• já pronto/

    patch schedule_mark_path(line, date: "2026-10-13", mark: "produce")
    assert_equal "produce", line.reload.schedule_mark
  end

  test "a marca fica no item do pedido: aparece em qualquer período que inclua a entrega" do
    line = line_on(Date.new(2026, 10, 14))
    patch schedule_mark_path(line, mark: "ready")
    [ "2026-10-11", "2026-10-14" ].each do |start|
      get schedule_path(date: start)
      assert_select "tr#linha-#{line.id} button[aria-pressed=true]"
    end
  end

  test "marca inválida não grava" do
    line = line_on(Date.new(2026, 10, 14))
    patch schedule_mark_path(line, mark: "meio")
    assert_equal "produce", line.reload.schedule_mark
  end

  test "quem é da produção vê a marca, mas não muda" do
    line = line_on(Date.new(2026, 10, 14))
    sign_in_as(user_for(:production))
    get schedule_path(date: "2026-10-13")
    assert_select "tr#linha-#{line.id} td", /□ produzir no dia/
    assert_select "tr#linha-#{line.id} button", count: 0
    patch schedule_mark_path(line, mark: "ready")
    assert_redirected_to production_path
    assert_equal "produce", line.reload.schedule_mark
  end

  test "o PDF sai com o período" do
    get schedule_path(date: "2026-10-13", format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end
end
