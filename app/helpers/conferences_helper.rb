module ConferencesHelper
  STATUS_ORDER = %i[unmatched different only_sheet not_comparable only_system ok].freeze

  # Diferenças sem motivo primeiro, depois as explicadas, depois o que bate.
  def comparison_sorted(rows)
    rows.sort_by { |row| [ row.ok? ? 1 : 0, row.explained? ? 1 : 0, STATUS_ORDER.index(row.status), row.label ] }
  end

  def comparison_value(row, field)
    return row.planilha_text if field == :planilha && row.planilha_text

    value = row.public_send(field)
    value.nil? ? "-" : "#{qty(value)} #{row.unit}".strip
  end

  def comparison_row_class(row)
    return "is-ok" if row.ok?
    return "is-changed" if (row.scored? && !row.explained?) || row.status == :unmatched

    nil
  end

  # Diferença que a equipe pode explicar com uma nota (o que bate ou não foi reconhecido não precisa).
  def comparison_notable?(row) = !row.ok? && row.status != :unmatched

  def comparison_week_text(week) = "#{short_date(week)} a #{short_date(week + 6)}"

  def unmatched_where(item)
    item.lines.map { |sheet, line| "#{SheetComparison::SECTION_LABELS.fetch(line.section).downcase} #{short_date(sheet.date)}" }.uniq.to_sentence
  end

  # "Programação · Ter 13/10" de uma aba importada.
  def sheet_title(sheet) = "#{SheetComparison::KINDS.fetch(sheet.kind.to_sym)} · #{weekday_date(sheet.date)}"

  # Resumo de uma versão no histórico: "primeira importação", "sem mudanças" ou "3 mudanças".
  def version_summary(version)
    return "primeira importação, #{plural(version.lines.size, 'linha', 'linhas')}" if version.version == 1

    changes = version.changes_from_previous.size
    changes.zero? ? "sem mudanças" : plural(changes, "mudança", "mudanças")
  end

  def sheet_import_text(import)
    [ l(import.created_at, format: "%d/%m às %H:%M"), import.user&.name ].compact.join(" · ")
  end
end
