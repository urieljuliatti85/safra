# Compara o que o Safra tem e calcula com o que foi feito à mão nas planilhas importadas (ReferenceSheet: abas da
# 01 - PROG. DE PRODUÇÃO contra os pedidos, da 02 - PLANILHA DE PRODUÇÃO contra a produção e da 03 - COMPRAS CEASA
# contra as compras). Devolve as diferenças, cada uma com o motivo provável, em vez de falhar: ainda não conhecemos
# todas as regras (ver docs/duvidas.md). Uma nota da equipe (ComparisonNote) explica a diferença enquanto os números
# não mudarem.
class SheetComparison
  STATUS_LABELS = {
    ok: "igual", different: "diferente", only_sheet: "só na planilha", only_system: "só no Safra",
    not_comparable: "não comparável", unmatched: "nome não reconhecido"
  }.freeze

  REASONS = {
    noted: "Explicado pela equipe",
    other_day: "Data de entrega diferente",
    other_customer: "Lançado em outro cliente",
    other_product: "Outro produto da mesma matéria-prima",
    lead_time: "Outro dia de produção (antecedência)",
    no_order: "Nenhum pedido no Safra leva a isso",
    follows_cuts: "Segue a diferença nos cortes",
    descasc_sector: "Descascado inteiro: a planilha anota no descascador",
    not_modeled: "O Safra ainda não calcula o descascador",
    missing_box: "Falta kg por caixa descascada no cadastro",
    missing_package: "Falta kg por embalagem no cadastro",
    missing_factor: "Falta fator de rendimento no cadastro",
    other_unit: "O pedido está em outra unidade",
    stock: "Estoque da câmara fria abatido",
    rounding: "Diferença de 1 embalagem",
    not_purchase_day: "Não é dia de compra no Safra",
    not_in_sheet: "Não está na planilha",
    text: "Quantidade em texto",
    unmatched: "Ligue o nome a um item do cadastro",
    unexplained: "Sem regra que explique"
  }.freeze

  # Motivos que apontam para o cadastro da matéria-prima.
  CATALOG_REASONS = %i[missing_box missing_package missing_factor].freeze

  # Cortes cuja regra já está confirmada: produzidos no dia da entrega.
  CONFIRMED_SAME_DAY_CUTS = %w[ralado picado rodelas].freeze
  NEIGHBOR_DAYS = 3

  SECTION_LABELS = { "programacao" => "Programação", "cortes" => "Cortes", "aprontes" => "Aprontes", "descascador" => "Descascador",
                     "compras" => "Compras" }.freeze
  KINDS = { schedule: "Programação", production: "Produção", purchase: "Compras CEASA" }.freeze

  Row = Data.define(:kind, :section, :date, :record, :label, :planilha, :planilha_text, :sistema, :unit, :status, :reason, :detail,
                    :note, :note_stale) do
    def initialize(note: nil, note_stale: false, **rest) = super
    def ok? = status == :ok
    def code = record&.code
    def key = [ kind, section, date, code || label ]
    def different? = %i[different only_sheet only_system].include?(status)
    # Entra no placar: a planilha tem um número e o item foi reconhecido.
    def scored? = %i[ok different only_sheet].include?(status) && !planilha.nil?
    def explained? = reason.present? && %i[unexplained unmatched].exclude?(reason)
    def status_label = SheetComparison::STATUS_LABELS.fetch(status)
    def reason_label = reason && SheetComparison::REASONS.fetch(reason)
    def difference = planilha && sistema && (sistema - planilha)
    def cut_code = record.is_a?(Product) ? record.cut&.code : nil
  end

  Unmatched = Data.define(:target, :label, :lines)

  def self.fmt(value, unit = nil)
    return "-" if value.nil?

    "#{Formatting.qty(value)}#{unit ? " #{unit}" : ''}"
  end

  def initialize(company, dates: nil)
    @company = company
    @dates = dates
  end

  def sheets
    @sheets ||= with_tenant do
      scope = ReferenceSheet.includes(:lines).order(:kind, :date)
      scope = scope.where(date: @dates) if @dates
      scope.to_a
    end
  end

  # Cada comparação mora na sua classe (Schedule, Production, Purchase); aqui ficam as notas, o placar e o relatório.
  def schedule_rows
    @schedule_rows ||= with_tenant { with_notes(Schedule.new(**section_args).rows) }
  end

  def production_rows
    @production_rows ||= with_tenant { with_notes(Production.new(**section_args).rows) }
  end

  def purchase_rows
    @purchase_rows ||= with_tenant { with_notes(Purchase.new(**section_args).rows) }
  end

  def rows = schedule_rows + production_rows + purchase_rows

  def rows_for(kind) = { schedule: schedule_rows, production: production_rows, purchase: purchase_rows }.fetch(kind)

  # Placar: [iguais, total]. O total é o que a planilha tem e dá para comparar (não muda com as regras);
  # itens que só o sistema calcula, textos que não são número e nomes não reconhecidos não entram.
  def scores
    { schedule: score(schedule_rows), production: score(production_rows), purchase: score(purchase_rows) }
  end

  # Diferenças que entram no placar, por motivo: [[motivo, quantidade]], o mais comum primeiro.
  def reasons
    rows.select { |row| row.scored? && !row.ok? }.group_by(&:reason).map { |reason, list| [ reason, list.size ] }.sort_by { |_, n| -n }
  end

  def explained_count = rows.count { |row| row.scored? && !row.ok? && row.explained? }

  # Nomes da planilha que ainda não estão ligados a nada, um por nome (com as linhas onde aparecem). Na programação,
  # o cliente do bloco também precisa ser reconhecido.
  def unmatched
    @unmatched ||= with_tenant do
      sheets.flat_map { |sheet| sheet.lines.flat_map { |line| names_of(line).map { |target, label| [ target, label, sheet, line ] } } }
            .reject { |target, label, _, _| matcher.call(label, target) }
            .group_by { |target, label, _, _| [ target, ReferenceSheets::Matcher.key(label) ] }
            .map { |(target, _), list| Unmatched.new(target: target, label: list.first[1], lines: list.map { |_, _, sheet, line| [ sheet, line ] }) }
            .sort_by { |item| [ SheetAlias::TARGETS.reverse.index(item.target), item.label ] }
    end
  end

  def summary
    { programacao: schedule_rows.group_by(&:status_label).transform_values(&:size),
      producao: production_rows.group_by(&:status_label).transform_values(&:size),
      compras: purchase_rows.group_by(&:status_label).transform_values(&:size) }
  end

  def confirmed_same_day_rows
    with_tenant { production_rows.select { |row| row.section == "cortes" && CONFIRMED_SAME_DAY_CUTS.include?(row.cut_code) } }
  end

  def report
    lines = [ "CONFERÊNCIA COM AS PLANILHAS (#{sheets.map(&:date).uniq.sort.map { |d| d.strftime('%d/%m') }.join(', ')})", "=" * 60 ]
    { "PROGRAMAÇÃO" => schedule_rows, "PRODUÇÃO" => production_rows, "COMPRAS CEASA" => purchase_rows }.each do |title, list|
      lines << "" << title
      list.group_by(&:date).each do |date, day_rows|
        lines << "" << "  #{date.strftime('%d/%m')} (#{day_rows.count(&:ok?)}/#{day_rows.count(&:scored?)} iguais)"
        day_rows.sort_by { |r| [ r.ok? ? 1 : 0, r.section, r.label ] }.each do |r|
          lines << format("    %-12s %-28s planilha=%-14s sistema=%-10s %-16s %s", r.section, r.label.truncate(28), r.planilha_text || SheetComparison.fmt(r.planilha, r.unit),
                          SheetComparison.fmt(r.sistema, r.unit), r.status_label, [ r.reason_label, r.detail ].compact.join(": "))
        end
      end
    end
    lines.join("\n")
  end

  private

  def with_tenant(&) = ActsAsTenant.with_tenant(@company, &)

  def matcher = @matcher ||= ReferenceSheets::Matcher.new

  def names_of(line) = [ [ line.target, line.label ], ([ "customer", line.group_label ] if line.group_label) ].compact

  def section_args = { sheets: sheets, matcher: matcher, company: @company, dates: @dates }

  # Nota que ainda vale (mesmos números) vira o motivo; nota antiga fica à mostra, sem explicar.
  def with_notes(list)
    @notes ||= ComparisonNote.all.index_by(&:key)
    list.map do |row|
      note = @notes[ComparisonNote.key_for(row)]
      next row if note.nil? || row.ok?
      next row.with(note: note, note_stale: true) unless note.current_for?(row)

      row.with(reason: :noted, detail: note.note, note: note)
    end
  end

  def score(list)
    scored = list.select(&:scored?)
    [ scored.count(&:ok?), scored.size ]
  end
end
