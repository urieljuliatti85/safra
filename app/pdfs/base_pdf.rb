require "prawn"
require "prawn/table"

# Os nomes têm acentos do português, todos dentro do WinAnsi da Helvetica nativa; o aviso genérico só atrapalha.
Prawn::Fonts::AFM.hide_m17n_warning = true

# Base dos PDFs (A4, Helvetica nativa do PDF: cobre os acentos do português).
class BasePdf
  GREEN = "2F6B3A".freeze
  GREY = "EEEEEE".freeze

  def initialize
    @pdf = Prawn::Document.new(page_size: "A4", margin: [ 36, 36, 40, 36 ])
    @pdf.font "Helvetica"
    @pdf.font_size 10
  end

  def render
    build
    number_pages
    @pdf.render
  end

  private

  attr_reader :pdf

  def title(text, subtitle = nil)
    pdf.text text, size: 16, style: :bold, color: GREEN
    pdf.text subtitle, size: 9, color: "555555" if subtitle
    pdf.move_down 8
  end

  def section(text)
    pdf.move_down 6
    pdf.fill_color GREEN
    pdf.text text, size: 11, style: :bold
    pdf.fill_color "000000"
    pdf.move_down 3
  end

  def table(header, rows, widths: nil, right: [])
    data = [ header ] + rows
    options = { header: true, width: pdf.bounds.width, cell_style: { size: 9, padding: [ 3, 4 ], border_color: "CCCCCC", border_width: 0.5 } }
    options[:column_widths] = widths if widths
    pdf.table(data, options) do |t|
      t.row(0).background_color = GREY
      t.row(0).font_style = :bold
      right.each { |col| t.column(col).align = :right }
    end
    pdf.move_down 6
  end

  def number_pages
    pdf.number_pages "Safra · página <page> de <total>", at: [ pdf.bounds.left, -20 ], align: :right, size: 8, color: "777777"
  end
end
