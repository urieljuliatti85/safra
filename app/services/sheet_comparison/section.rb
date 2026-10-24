class SheetComparison
  # Base das três comparações (programação, produção, compras): ler as linhas da planilha, somar e decidir o status.
  class Section
    def initialize(sheets:, matcher:, company:, dates:)
      @sheets = sheets
      @matcher = matcher
      @company = company
      @dates = dates
    end

    private

    attr_reader :matcher

    def sheets_of(kind) = @sheets.select { |sheet| sheet.kind == kind }

    # Linhas reconhecidas agrupadas por seção e item; as não reconhecidas vão em :unmatched. Ignoradas somem.
    def classify(sheet)
      sheet.lines.each_with_object(Hash.new { |h, k| h[k] = [] }) do |line, groups|
        match = matcher.call(line.label, line.target)
        next if match&.ignored

        groups[match ? [ line.section, match.record ] : [ :unmatched, line ]] << line
      end
    end

    # [quantidade somada, texto]: com qualquer linha em texto (ou em outra unidade), a soma não vale e fica o texto.
    def total(lines, unit = nil)
      return [ nil, nil ] if lines.blank?

      numeric = lines.all? { |line| line.quantity && (unit.nil? || line.unit == unit) }
      numeric ? [ lines.sum(&:quantity), nil ] : [ nil, lines.map(&:quantity_text).join(" + ") ]
    end

    def status_for(planilha, text, sistema)
      return :not_comparable if planilha.nil? && text
      return :only_system if planilha.nil?
      return :only_sheet if sistema.nil?

      (planilha - sistema).abs < 0.0005 ? :ok : :different
    end

    def same?(a, b) = a && b && (a - b).abs < 0.0005

    def neighbor_days(date) = ((date - NEIGHBOR_DAYS)..(date + NEIGHBOR_DAYS)).reject { |day| day == date || day.sunday? }

    def unmatched_rows(kind, sheet, groups)
      groups.select { |(section, _), _| section == :unmatched }.map do |(_, line), _|
        Row.new(kind: kind, section: line.section, date: sheet.date, record: nil, label: line.label, planilha: line.quantity,
                planilha_text: line.quantity.nil? ? line.quantity_text : nil, sistema: nil, unit: line.unit, status: :unmatched, reason: :unmatched, detail: nil)
      end
    end

    def fmt(value, unit = nil) = SheetComparison.fmt(value, unit)
  end
end
