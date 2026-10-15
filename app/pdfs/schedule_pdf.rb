class SchedulePdf < BasePdf
  def initialize(date:, groups:)
    super()
    @date = date
    @groups = groups
  end

  private

  def build
    title "Programação de entregas", Formatting.weekday_date(@date) + "/#{@date.year}"
    pdf.text "Nenhuma entrega neste dia." if @groups.empty?
    @groups.each do |group|
      section group.customer.name
      rows = group.entries.map do |e|
        [ e.product.name, Formatting.qty(e.quantity), e.unit, e.production_date ? Formatting.weekday_date(e.production_date) : "compra (in natura)" ]
      end
      table %w[Produto Qtd. Un. Produzir\ em], rows, widths: { 0 => 260, 1 => 55, 2 => 40 }, right: [ 1 ]
    end
  end
end
