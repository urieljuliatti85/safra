require "test_helper"

# Tipo de pedido (R1.29 a R1.33, D22): pedido novo e alteração gravam o total; o extra soma ao que já estava.
class OrderEntryTypeTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2026, 10, 5, 9) # antes das 48 h da entrega
    ActsAsTenant.current_tenant = company
    @order = Order.find_by!(customer: Customer.find_by!(code: "hnorte"), week_start: Date.new(2026, 10, 12))
    @product = Product.find_by!(code: "cenoura_ralada")
    @key = "#{@product.id}|kg"
    @current = quantity("2026-10-14")
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def quantity(date) = @order.lines.reload.where(product: @product, delivery_date: date).sum(:quantity)
  def save(cells, **options) = OrderGridSaver.new(order: @order, quantities: { @key => cells }, **options).call

  test "alteração grava o novo total e a versão guarda o tipo" do
    assert save({ "2026-10-14" => "20" }, entry_type: "alteration").ok?
    assert_equal 20, quantity("2026-10-14")
    version = @order.versions.order(:version).last
    assert_equal "alteration", version.entry_type
    assert_equal "Grade · Alteração", version.source_label
  end

  test "extra soma ao que já estava; vazio não muda nada" do
    assert @current.positive?
    other = @order.lines.where(product: @product).where.not(delivery_date: "2026-10-14").first
    assert save({ "2026-10-14" => "20", other.delivery_date.iso8601 => "" }, entry_type: "extra").ok?
    assert_equal @current + 20, quantity("2026-10-14")
    assert_equal other.quantity, quantity(other.delivery_date)
    change = @order.versions.order(:version).last.changes_list.sole
    assert_equal [ @current.to_s("F").sub(/\.0\z/, ""), (@current + 20).to_s("F").sub(/\.0\z/, "") ], change.values_at("before", "after")
  end

  test "extra de produto que não estava na data entra com a quantidade pedida" do
    product = Product.find_by!(code: "jilo_cubos")
    assert OrderGridSaver.new(order: @order, quantities: { "#{product.id}|kg" => { "2026-10-14" => "5" } }, entry_type: "extra").call.ok?
    assert_equal 5, @order.lines.where(product: product, delivery_date: "2026-10-14").sum(:quantity)
  end

  test "extra a menos de 48 h não pede a confirmação (o prazo do extra espera a A.5); alteração pede" do
    travel_to Time.zone.local(2026, 10, 14, 8) do
      assert save({ "2026-10-14" => "5" }, entry_type: "extra").ok?
      assert_not save({ "2026-10-14" => "5" }, entry_type: "alteration").ok?
    end
  end

  test "tipo desconhecido é recusado" do
    assert_equal [ "Tipo de pedido inválido." ], save({ "2026-10-14" => "5" }, entry_type: "soma").errors
  end
end
