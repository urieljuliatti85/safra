class PurchasePdf < BasePdf
  def initialize(date:, suppliers:, version:, changed: false)
    super()
    @date = date
    @suppliers = suppliers
    @version = version
    @changed = changed
  end

  private

  def build
    header "Compras CEASA · #{Formatting.weekday_date(@date)}/#{@date.year}", nil, @version, changed: @changed
    pdf.text "Nada a comprar neste dia." if @suppliers.empty?
    @suppliers.each do |supplier, needs|
      section supplier, "#{needs.size} #{needs.size == 1 ? 'item' : 'itens'}"
      rows = needs.map do |n|
        [ n.raw_material.name, "#{Formatting.qty(n.kg)} #{n.unit}", n.stock_kg.positive? ? "#{Formatting.qty(n.stock_kg)} kg" : "-", Formatting.need_text(n) ]
      end
      table [ "MATÉRIA-PRIMA", "NECESSIDADE", "ESTOQUE", "COMPRAR" ], rows, widths: { 1 => 100, 2 => 80, 3 => 100 }, right: [ 1, 2, 3 ], big: 3
    end
  end
end
