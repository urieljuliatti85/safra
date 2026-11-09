require "test_helper"

# Alteração com menos de 48 h da entrega pede a confirmação da Hortifruti Modelo (R1.26, D8).
class OrderAlterationNoticeTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @customer = Customer.find_by!(code: "hnorte")
    @order = Order.find_by!(customer: @customer, week_start: Date.new(2026, 10, 12))
    @product = Product.find_by!(code: "cenoura_ralada")
    @key = "#{@product.id}|kg"
    @current = @order.lines.where(product: @product, delivery_date: "2026-10-14").sum(:quantity)
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def save(cells, **options) = OrderGridSaver.new(order: @order, quantities: { @key => cells }, **options).call

  test "mudar com menos de 48 h é recusado sem a confirmação e gravado com ela, que fica na versão" do
    travel_to Time.zone.local(2026, 10, 12, 10) do
      result = save({ "2026-10-14" => "99" })
      assert_equal [ "Cenoura ralada em 14/10: falta menos de 48 h para a entrega. Marque \"A Hortifruti Modelo confirmou a alteração\" para gravar." ],
                   result.errors
      assert_equal @current, @order.lines.where(product: @product, delivery_date: "2026-10-14").sum(:quantity)

      assert save({ "2026-10-14" => "99" }, late_confirmed: true).ok?
      assert @order.versions.order(:version).last.late_confirmed?
      assert_match "confirmada com menos de 48 h", @order.versions.order(:version).last.source_label
    end
  end

  test "com 48 h ou mais não pede; produto novo no dia (pedido extra) fica de fora até a A.5" do
    travel_to Time.zone.local(2026, 10, 11, 23) { assert save({ "2026-10-14" => "99" }).ok? }

    travel_to Time.zone.local(2026, 10, 14, 8) do
      new_product = Product.find_by!(code: "jilo_cubos")
      assert OrderGridSaver.new(order: @order, quantities: { "#{new_product.id}|kg" => { "2026-10-14" => "5" } }).call.ok?
    end
  end

  test "as 48 h contam do início da janela de entrega do cliente" do
    @customer.update!(delivery_from: "15:00")
    travel_to(Time.zone.local(2026, 10, 12, 14, 59)) { assert save({ "2026-10-14" => "98" }).ok? }
    travel_to(Time.zone.local(2026, 10, 12, 15, 1)) { assert_not save({ "2026-10-14" => "97" }).ok? }
  end

  test "restaurar uma versão não pede a confirmação" do
    travel_to(Time.zone.local(2026, 10, 10, 9)) { save({ "2026-10-14" => "99" }) }
    travel_to Time.zone.local(2026, 10, 14, 8) do
      assert OrderVersionRestorer.new(version: @order.versions.order(:version).first).call.ok?
    end
  end

  test "a prévia diz o que pediria a confirmação, sem gravar; a grade mostra os dias" do
    preview = ->(cells) { OrderGridSaver.new(order: @order, quantities: { @key => cells }).late_alterations_preview }
    travel_to Time.zone.local(2026, 10, 12, 10) do
      assert_equal [ "Cenoura ralada em 14/10" ], preview.call({ "2026-10-14" => "99" })
      assert_empty preview.call({ "2026-10-14" => @current.to_s("F") })
      assert_equal @current, @order.lines.where(product: @product, delivery_date: "2026-10-14").sum(:quantity)
      assert_includes OrderGrid.new(order: @order).late_dates, Date.new(2026, 10, 14)
    end
    travel_to Time.zone.local(2026, 10, 5, 9) do
      assert_empty preview.call({ "2026-10-14" => "99" })
      assert_empty OrderGrid.new(order: @order).late_dates
    end
  end
end
