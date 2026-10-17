require "prawn"
require "prawn/table"

# Base dos PDFs (A4, Bricolage Grotesque embutida: regular 420 e negrito 800). Feitos para ler sob luz forte, na bancada: tinta escura sobre branco,
# quantidades grandes e alinhadas à direita, uma faixa verde por setor.
class BasePdf
  INK = "14231A".freeze
  SOFT = "4A5D50".freeze
  FIELD = "2E7D32".freeze
  DEEP = "1E5A24".freeze
  WASH = "E7F1E2".freeze
  LINE = "CBD7C4".freeze
  SUN = "F2B705".freeze
  CHANGE = "B3261E".freeze

  FONT_DIR = Rails.root.join("app/pdfs/fonts")

  def initialize
    @pdf = Prawn::Document.new(page_size: "A4", margin: [ 44, 36, 44, 36 ])
    @pdf.font_families.update(
      "Bricolage" => { normal: FONT_DIR.join("BricolageGrotesque-Regular.ttf").to_s, bold: FONT_DIR.join("BricolageGrotesque-Bold.ttf").to_s }
    )
    @pdf.font "Bricolage"
    @pdf.font_size 10.5
    @pdf.fill_color INK
  end

  def render
    build
    repeat_running_header
    number_pages
    @pdf.render
  end

  private

  attr_reader :pdf

  # Título da folha + selo de versão (verde = enviada, contorno = rascunho).
  # changed: o conteúdo é o cálculo atual, que já difere da versão enviada; a folha não pode levar o selo dela.
  def header(title, subtitle, version, changed: false)
    draft_note = version && changed ? "difere da v#{version.version}" : "não enviado"
    version = nil if changed
    @running_title = "#{title} · #{version ? "v#{version.version} enviada" : 'rascunho'}"
    top = pdf.cursor
    pdf.fill_color DEEP
    pdf.text_box "Safra", at: [ 0, top ], size: 10, style: :bold, width: 120
    pdf.fill_color INK
    pdf.text_box title, at: [ 0, top - 14 ], size: 22, style: :bold, width: pdf.bounds.width - 130
    stamp(version, top, draft_note)
    pdf.move_down 44
    pdf.fill_color SOFT
    pdf.text subtitle, size: 10 if subtitle.present?
    pdf.fill_color INK
    pdf.move_down 8
  end

  def stamp(version, top, draft_note)
    label = version ? "v#{version.version} enviada" : "RASCUNHO"
    sub = version ? version.sent_at.strftime("%d/%m às %H:%M") : draft_note
    width = 112
    left = pdf.bounds.width - width
    pdf.save_graphics_state do
      if version
        pdf.fill_color FIELD
        pdf.fill_rounded_rectangle [ left, top ], width, 38, 6
        pdf.fill_color "FFFFFF"
      else
        pdf.stroke_color SOFT
        pdf.line_width 1.2
        pdf.stroke_rounded_rectangle [ left, top ], width, 38, 6
        pdf.fill_color INK
      end
      pdf.text_box label, at: [ left, top - 6 ], width: width, align: :center, size: 12, style: :bold
      pdf.text_box sub, at: [ left, top - 22 ], width: width, align: :center, size: 8.5
    end
  end

  # Faixa de setor: verde-claro com texto verde-escuro e contagem à direita.
  def section(text, meta = nil)
    pdf.start_new_page if pdf.cursor < 90
    pdf.move_down 8
    top = pdf.cursor
    pdf.fill_color WASH
    pdf.fill_rectangle [ 0, top ], pdf.bounds.width, 22
    pdf.fill_color DEEP
    pdf.text_box text, at: [ 8, top - 5 ], size: 12, style: :bold, width: pdf.bounds.width - 120
    pdf.text_box meta, at: [ pdf.bounds.width - 108, top - 6 ], size: 9.5, align: :right, width: 100 if meta
    pdf.fill_color INK
    pdf.move_down 24
  end

  # right: colunas alinhadas à direita; big: coluna de quantidade em corpo maior; flagged: índices de linha em vermelho.
  def table(header, rows, widths: nil, right: [], big: nil, flagged: [])
    data = [ header ] + rows
    options = { header: true, width: pdf.bounds.width,
                cell_style: { size: 10.5, padding: [ 5, 6 ], border_width: 0, border_color: LINE, text_color: INK } }
    options[:column_widths] = widths if widths
    pdf.table(data, options) do |t|
      t.row(0).size = 9
      t.row(0).font_style = :bold
      t.row(0).text_color = SOFT
      t.row(0).borders = [ :bottom ]
      t.row(0).border_width = 0.8
      t.rows(1..-1).borders = [ :bottom ]
      t.rows(1..-1).border_width = 0.4
      right.each { |col| t.column(col).align = :right }
      if big
        t.column(big).rows(1..-1).size = 14
        t.column(big).rows(1..-1).font_style = :bold
      end
      flagged.each { |index| t.row(index + 1).text_color = CHANGE }
    end
    pdf.move_down 6
  end

  # Folha solta na bancada precisa dizer de que dia é: título e versão se repetem nas páginas seguintes.
  def repeat_running_header
    title = @running_title
    return unless title

    pdf.repeat(->(page) { page > 1 }, dynamic: true) do
      pdf.fill_color SOFT
      pdf.text_box title, at: [ 0, pdf.bounds.top + 22 ], width: pdf.bounds.width, size: 9, style: :bold
      pdf.stroke_color LINE
      pdf.line_width 0.5
      pdf.stroke_horizontal_line 0, pdf.bounds.width, at: pdf.bounds.top + 8
      pdf.fill_color INK
    end
  end

  def number_pages
    pdf.number_pages "Safra · página <page> de <total>", at: [ pdf.bounds.left, -24 ], align: :right, size: 8, color: SOFT
  end
end
