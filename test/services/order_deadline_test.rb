require "test_helper"

# Prazo do pedido semanal (R1.4, D7): 15h da quinta anterior à semana das entregas, comparado com a chegada do pedido.
class OrderDeadlineTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @order = Order.find_by!(customer: Customer.find_by!(code: "hbp"), week_start: Date.new(2026, 10, 12))
    @order.update!(received_at: nil)
  end

  teardown { ActsAsTenant.current_tenant = nil }

  test "o prazo da semana de 12/10 é quinta 08/10 às 15h" do
    assert_equal Time.zone.local(2026, 10, 8, 15), @order.deadline

    @order.received_at = Time.zone.local(2026, 10, 8, 15)
    assert_not @order.late?
    @order.received_at = Time.zone.local(2026, 10, 8, 15, 1)
    assert @order.late?
  end

  test "sem data de chegada não há atraso, e a Nutrir não segue o prazo semanal" do
    assert_not @order.late?

    nutrir = Order.find_or_create_by!(customer: Customer.find_by!(code: "nutrir"), week_start: Date.new(2026, 10, 12))
    nutrir.received_at = Time.zone.local(2026, 10, 10, 9)
    assert_not nutrir.late?
  end

  test "a conferência avisa o pedido que chegou depois do prazo" do
    @order.update!(received_at: Time.zone.local(2026, 10, 9, 16, 20))
    alerts = ConferenceChecker.new(company: company, week: Date.new(2026, 10, 12)).call.select { |a| a.kind == "Prazo" }

    assert_equal [ "Bom Pastor: pedido da semana de 12/10 recebido em Sex 09/10 às 16:20, depois do prazo (Qui 08/10, 15h)." ],
                 alerts.map(&:message)
    assert_equal :warn, alerts.first.level
  end

  test "o primeiro salvamento marca a chegada; uma chegada já informada não muda" do
    key = "#{Product.find_by!(code: 'cenoura_cubinhos').id}|kg"
    travel_to(Time.zone.local(2026, 10, 7, 10)) do
      OrderGridSaver.new(order: @order, quantities: { key => { "2026-10-13" => "41" } }).call
    end
    assert_equal Time.zone.local(2026, 10, 7, 10), @order.reload.received_at

    OrderGridSaver.new(order: @order, quantities: { key => { "2026-10-13" => "42" } }).call
    assert_equal Time.zone.local(2026, 10, 7, 10), @order.reload.received_at
  end
end
