require "test_helper"

class ConferenceCheckerTest < ActiveSupport::TestCase
  test "alerta, sem erro, sobre fator ausente, unidades e observações do pedido" do
    alerts = ConferenceChecker.new(company: company).call
    messages = alerts.map(&:message)
    assert(messages.any? { |m| m.include?("Cebola") && m.include?("sem fator") })
    assert(messages.any? { |m| m.include?("Pedido diz 1 un; a programação usa 100") })
    assert(alerts.any? { |a| a.kind == "Unidade" })
    assert alerts.first.level == :warn
  end
end
