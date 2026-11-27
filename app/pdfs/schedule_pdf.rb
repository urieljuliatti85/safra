# Programação em quatro dias (R3.3, R3.4, D35): por cliente e data de entrega, com a marca de cada item.
class SchedulePdf < BasePdf
  # A fonte do PDF não tem "□": o quadrado (produzir no dia) e o ponto (já pronto) são desenhados.
  class MarkCell < Prawn::Table::Cell
    SIZE = 9

    def initialize(pdf, mark)
      super(pdf, [ 0, 0 ])
      @mark = mark
    end

    def natural_content_width = SIZE
    def natural_content_height = SIZE

    def draw_content
      @pdf.stroke_color BasePdf::INK
      if @mark == "ready"
        @pdf.fill_color BasePdf::INK
        @pdf.fill_circle [ SIZE / 2.0, SIZE / 2.0 + 2 ], 3
      else
        @pdf.line_width 0.9
        @pdf.stroke_rectangle [ 0, SIZE + 2 ], SIZE, SIZE
      end
    end
  end

  def initialize(date:, end_date:, groups:)
    super()
    @date = date
    @end_date = end_date
    @groups = groups
  end

  private

  def build
    period = "#{Formatting.weekday_date(@date)} a #{Formatting.weekday_date(@end_date)}/#{@end_date.year}"
    header "Programação de entregas", "#{period} · quadrado: produzir no dia · ponto: já pronto", nil
    pdf.text "Nenhuma entrega neste período." if @groups.empty?
    @groups.each do |group|
      section group.customer.name, "#{group.entries.size} itens"
      rows = group.entries.map do |e|
        [ MarkCell.new(pdf, e.mark), Formatting.weekday_date(e.delivery_date), e.product.name, Formatting.qty(e.quantity), e.unit ]
      end
      table [ "", "ENTREGA", "PRODUTO", "QTD.", "UN." ], rows, widths: { 0 => 24, 1 => 70, 2 => 250, 3 => 60 }, right: [ 3 ], big: 3
    end
  end
end
