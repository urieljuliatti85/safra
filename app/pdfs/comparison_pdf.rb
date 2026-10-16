# Relatório da semana do teste em paralelo: placar das planilhas contra o Safra e cada diferença com o motivo,
# para mostrar à empresa. Diferença sem regra que explique sai em vermelho; o que bate entra só na contagem.
class ComparisonPdf < BasePdf
  def initialize(comparison:, week:)
    super()
    @comparison = comparison
    @week = week
  end

  private

  def build
    @running_title = "Planilhas × Safra · semana de #{week_text}"
    pdf.fill_color DEEP
    pdf.text "Safra", size: 10, style: :bold
    pdf.fill_color INK
    pdf.text "Planilhas × Safra", size: 22, style: :bold
    pdf.fill_color SOFT
    pdf.text "Semana de #{week_text}. Números das planilhas feitas à mão ao lado do que o Safra tem e calcula.", size: 10
    pdf.fill_color INK
    pdf.move_down 10

    scores
    reasons
    SheetComparison::KINDS.each do |kind, title|
      @comparison.rows_for(kind).group_by(&:date).sort.each { |date, rows| day(title, date, rows) }
    end
  end

  def week_text = "#{Formatting.short_date(@week)} a #{Formatting.short_date(@week + 6)}/#{@week.year}"

  def scores
    all = @comparison.scores
    rows = SheetComparison::KINDS.filter_map do |kind, title|
      equal, total = all.fetch(kind)
      [ title, total.zero? ? "sem planilha" : "#{equal} de #{total} iguais" ]
    end
    differences = @comparison.reasons.sum(&:last)
    rows << [ "Diferenças com motivo", "#{@comparison.explained_count} de #{differences}" ]
    table [ "PLACAR", "" ], rows, widths: { 1 => 160 }, right: [ 1 ]
  end

  def reasons
    return if @comparison.reasons.empty?

    section "Diferenças por motivo"
    rows = @comparison.reasons.map { |reason, count| [ SheetComparison::REASONS.fetch(reason), count.to_s ] }
    flagged = @comparison.reasons.each_index.select { |i| @comparison.reasons[i].first == :unexplained }
    table [ "MOTIVO", "ITENS" ], rows, widths: { 1 => 60 }, right: [ 1 ], flagged: flagged
  end

  def day(title, date, rows)
    shown = rows.reject { |row| row.ok? || (row.status == :only_system && row.reason == :not_in_sheet) }
    equal = rows.count(&:ok?)
    section "#{title} · #{Formatting.weekday_date(date)}", "#{equal} de #{rows.count(&:scored?)} iguais"
    if shown.empty?
      pdf.text "Tudo igual.", size: 10
      pdf.move_down 4
      return
    end

    shown = shown.sort_by { |row| [ row.explained? ? 1 : 0, row.section, row.label ] }
    lines = shown.map do |row|
      item = %w[cortes compras].include?(row.section) ? row.label : "#{SheetComparison::SECTION_LABELS.fetch(row.section, row.section)}: #{row.label}"
      [ item, value(row, :planilha), value(row, :sistema), [ row.status_label, row.reason_label, row.detail ].compact.join(" · ") ]
    end
    flagged = shown.each_index.select { |i| !shown[i].explained? }
    table [ "ITEM", "PLANILHA", "SAFRA", "SITUAÇÃO E MOTIVO" ], lines, widths: { 0 => 150, 1 => 66, 2 => 66 }, right: [ 1, 2 ], flagged: flagged
  end

  def value(row, field)
    return row.planilha_text if field == :planilha && row.planilha_text

    number = row.public_send(field)
    number.nil? ? "-" : "#{Formatting.qty(number)} #{row.unit}".strip
  end
end
