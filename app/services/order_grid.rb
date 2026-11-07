# Linhas e células da grade de pedidos de um cliente/semana, para a tela de pedidos e a de pedido em imagem.
class OrderGrid
  attr_reader :order, :dates, :rows, :sections, :cells, :available_products

  def initialize(order:, add_product: nil)
    @order = order
    @dates = order.week_dates.to_a
    lines = order.lines.includes(:product).to_a
    @cells = lines.group_by { |l| [ l.product_id, l.unit ] }
    rows = @cells.keys.map { |product_id, unit| [ lines.find { |l| l.product_id == product_id }.product, unit ] }
    rows << [ add_product, add_product.unit ] if add_product && rows.none? { |p, u| p == add_product && u == add_product.unit }
    @rows = rows.sort_by { |product, unit| [ Product::GROUPS.index(product.product_group), product.name, unit ] }
    @sections = @rows.group_by { |product, _| product.product_group }
    @available_products = Product.order(:name).includes(:raw_material)
  end
end
