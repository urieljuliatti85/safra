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
        [ n.raw_material.name, Formatting.need_text(n) ]
      end
      table [ "MATÉRIA-PRIMA", "VOLUME TOTAL" ], rows, widths: { 1 => 120 }, right: [ 1 ], big: 1
    end
  end
end
