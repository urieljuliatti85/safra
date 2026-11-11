require "test_helper"

# Item que já estava no pedido só sai pelo "Cancelar item" (R1.38, D23): vazio ou 0 não apaga, e a versão registra
# "cancelado". No extra, a grade mostra atual + acréscimo = total antes de salvar (R1.37).
class OrderCancelItemsTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 10, 5, 9) # antes das 48 h das entregas da semana de 12/10
    sign_in_as(user_for(:office))
    @product, @order = ActsAsTenant.with_tenant(company) do
      [ Product.find_by!(code: "cenoura_cubinhos"), Order.find_by!(customer: Customer.find_by!(code: "hbp"), week_start: Date.new(2026, 10, 12)) ]
    end
    @line = ActsAsTenant.with_tenant(company) { @order.lines.where(product: @product).order(:delivery_date).first }
    @row = "#{@product.id}|#{@line.unit}"
  end

  def quantity(date = @line.delivery_date)
    ActsAsTenant.with_tenant(company) { @order.lines.where(product: @product, delivery_date: date).sum(:quantity) }
  end

  def cancel(days, **params)
    patch order_cancel_items_path(customer: "hbp", week: "2026-10-12"),
          params: { row: @row, cancel: days.map { |date| "#{@row}|#{date.iso8601}" } }.merge(params)
  end

  test "vazio ou 0 na grade não tira item que já estava e explica o Cancelar item" do
    [ "", "0" ].each do |typed|
      patch orders_path(customer: "hbp", week: "2026-10-12"),
            params: { entry_type: "alteration", quantities: { @row => { @line.delivery_date.iso8601 => typed } } }
      assert_response :unprocessable_entity
      assert_match "vazio ou 0 não tira item do pedido", response.body
      assert_match "Cancelar item", response.body
      assert_equal @line.quantity, quantity
    end
  end

  test "linha nova sem quantidade continua sendo descartada sem erro" do
    jilo = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "jilo_cubos") }
    patch orders_path(customer: "hbp", week: "2026-10-12"),
          params: { entry_type: "alteration", quantities: { "#{jilo.id}|kg" => { "2026-10-14" => "" } } }
    assert_redirected_to orders_path(customer: "hbp", week: Date.new(2026, 10, 12))
  end

  test "a grade mostra Cancelar item com os dias do produto" do
    get orders_path(customer: "hbp", week: "2026-10-12")
    assert_select "form#cancel-items-form[action^=?]", order_cancel_items_path
    assert_select "details.cancel-item summary", /Cancelar item/
    assert_select "input[type=checkbox][form=cancel-items-form][value=?]", "#{@row}|#{@line.delivery_date.iso8601}"
    assert_select "button[form=cancel-items-form][name=row][value=?]", @row, text: /Confirmar cancelamento/
    assert_select ".savebar", /Vazio ou 0 não tira item do pedido/
  end

  test "Cancelar item tira o dia marcado e a versão registra cancelado" do
    cancel([ @line.delivery_date ])
    assert_redirected_to orders_path(customer: "hbp", week: Date.new(2026, 10, 12))
    follow_redirect!
    assert_match "Item cancelado: versão", response.body
    assert_select "section#versoes li", /Item cancelado/
    assert_equal 0, quantity

    version = ActsAsTenant.with_tenant(company) { @order.versions.order(:version).last }
    assert_equal "cancel", version.source
    change = version.changes_list.sole
    assert_equal [ true, nil ], change.values_at("cancelled", "after")
    get order_version_path(version)
    assert_select "td", "cancelado"
  end

  test "Cancelar item sem dia marcado, ou com dia de outra linha, não muda nada" do
    cancel([])
    assert_equal "Marque o dia do item a cancelar.", flash[:alert]

    other = ActsAsTenant.with_tenant(company) { @order.lines.where.not(product: @product).first }
    patch order_cancel_items_path(customer: "hbp", week: "2026-10-12"),
          params: { row: @row, cancel: [ "#{other.product_id}|#{other.unit}|#{other.delivery_date.iso8601}" ] }
    assert_equal "Marque o dia do item a cancelar.", flash[:alert]
    assert_equal other.quantity, ActsAsTenant.with_tenant(company) { other.reload.quantity }
  end

  test "com menos de 48 h da entrega, cancelar pede a confirmação da Hortifruti Modelo" do
    travel_to Time.zone.local(2026, 10, 12, 9)
    cancel([ @line.delivery_date ])
    assert_match "menos de 48 h", flash[:alert]
    assert_equal @line.quantity, quantity

    cancel([ @line.delivery_date ], late_confirmed: { @row => "1" })
    assert_equal 0, quantity
    assert ActsAsTenant.with_tenant(company) { @order.versions.order(:version).last.late_confirmed? }
  end

  test "volta para a tela de onde veio, só se for do próprio app" do
    cancel([ @line.delivery_date ], back: "https://exemplo.com/")
    assert_redirected_to orders_path(customer: "hbp", week: Date.new(2026, 10, 12))
  end

  test "no extra, cada célula traz a quantidade atual para mostrar o total ao digitar" do
    get orders_path(customer: "hbp", week: "2026-10-12", tipo: "extra")
    assert_select "form[data-controller~=extra-sum]"
    assert_select "input.cell-extra[data-current=?]", @line.quantity.to_s("F")
    assert_select "span.extra-sum"
    assert_select "details.cancel-item", 0
  end

  test "pedido em imagem também não apaga com vazio e cancela pela mesma ação" do
    post order_imports_path, params: { entry_type: "new", customer: "hbp", file: fixture_file_upload("imagem_pedido.png", "image/png") }
    import = ActsAsTenant.with_tenant(company) { OrderImport.images.order(:id).last }
    patch settings_order_import_path(import), params: { week: "2026-10-12" }

    patch grid_order_import_path(import), params: { entry_type: "alteration", quantities: { @row => { @line.delivery_date.iso8601 => "" } } }
    assert_response :unprocessable_entity
    assert_match "vazio ou 0 não tira item do pedido", response.body
    assert_equal @line.quantity, quantity

    get order_import_path(import)
    assert_select "form#cancel-items-form[action*=?]", CGI.escape(order_import_path(import))
  end
end
