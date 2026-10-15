class SchedulePdf < BasePdf
  def initialize(date:, groups:)
    super()
    @date = date
    @groups = groups
  end

  private

  def build
    header "Programação de entregas", "#{Formatting.weekday_date(@date)}/#{@date.year}", nil
    pdf.text "Nenhuma entrega neste dia." if @groups.empty?
    @groups.each do |group|
      section group.customer.name, "#{group.entries.size} itens"
      rows = group.entries.map do |e|
        [ e.product.name, Formatting.qty(e.quantity), e.unit, e.production_date ? Formatting.weekday_date(e.production_date) : "compra (in natura)" ]
      end
      table [ "PRODUTO", "QTD.", "UN.", "PRODUZIR EM" ], rows, widths: { 0 => 250, 1 => 60, 2 => 40 }, right: [ 1 ], big: 1
    end
  end
end
