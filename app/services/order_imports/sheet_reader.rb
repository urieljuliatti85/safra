require "roo"
require "roo-xls"

module OrderImports
  # Lê a grade semanal que os clientes mandam (xlsx, xls, ods, csv): produtos nas linhas, dias nas colunas.
  # Acha sozinho a linha das datas, a coluna do nome e a da unidade (quando existe). Linhas sem quantidade
  # são ignoradas; texto como "5 + 2" é somado e avisado; texto que não é número vira erro.
  class SheetReader
    Row = Data.define(:line, :name, :unit, :quantities, :warnings)
    Result = Data.define(:sheet, :title, :dates, :rows, :errors, :ignored_blank)

    UNITS = {
      "kg" => "kg", "quilograma" => "kg", "quilo" => "kg", "quilogramas" => "kg",
      "mç" => "mç", "mc" => "mç", "maço" => "mç", "maco" => "mç",
      "un" => "un", "und" => "un", "unid" => "un", "unidade" => "un", "unidades" => "un",
      "cx" => "cx", "caixa" => "cx",
      "crivo" => "crivo", "crivos" => "crivo", "pente" => "crivo", "pentes" => "crivo",
      "dz" => "dz", "duzia" => "dz", "dúzia" => "dz", "duzias" => "dz", "dúzias" => "dz"
    }.freeze
    SKIP_NAMES = /\A(total|valor|validade|periodo|período|fornecedor|contato|descri[cç][aã]o|produtos?)\b/i
    DATE_PATTERN = %r{\A(\d{4}-\d{2}-\d{2}|\d{2}/\d{2}/\d{4})\z}

    class Unreadable < StandardError; end

    def initialize(path, extension: nil)
      @path = path
      @extension = extension.to_s.delete_prefix(".").downcase.presence&.to_sym
    end

    def call
      book = open_book
      candidates = book.sheets.filter_map { |name| read_sheet(book.sheet(name), name) }
      raise Unreadable, "Não achei uma linha com as datas da semana em nenhuma aba." if candidates.empty?

      # Com várias abas (ex.: cotação e pedido), vale a que tem mais produtos com quantidade; empate, a menor.
      candidates.max_by { |c| [ c.rows.size, -c.ignored_blank ] }
    end

    private

    def open_book
      @extension ? Roo::Spreadsheet.open(@path, extension: @extension) : Roo::Spreadsheet.open(@path)
    rescue StandardError => e
      raise Unreadable, "Não consegui abrir o arquivo (#{e.message})."
    end

    def read_sheet(sheet, name)
      return nil if sheet.last_row.nil?

      date_row, date_columns = find_dates(sheet)
      return nil unless date_row

      name_col = sheet.first_column
      unit_col = find_unit_column(sheet, date_row, name_col, date_columns)
      errors = []
      ignored_blank = 0
      rows = ((date_row + 1)..sheet.last_row).filter_map do |line|
        product_name = sheet.cell(line, name_col).to_s.strip
        next if product_name.empty? || product_name.match?(SKIP_NAMES)

        warnings = []
        unit_warnings = []
        unit = read_unit(sheet, line, unit_col, unit_warnings)
        quantities = date_columns.to_h { |col, date| [ date, parse_quantity(sheet.cell(line, col), line, date, warnings, errors, unit) ] }
        # Linha só com célula deixada de fora por unidade diferente continua na conferência, para o aviso aparecer.
        if quantities.values.all?(&:nil?) && warnings.empty?
          ignored_blank += 1
          next
        end
        Row.new(line: line, name: product_name, unit: unit, quantities: quantities, warnings: warnings + unit_warnings)
      end
      Result.new(sheet: name, title: title_of(sheet, date_row), dates: date_columns.values, rows: rows, errors: errors, ignored_blank: ignored_blank)
    end

    def find_dates(sheet)
      (sheet.first_row..[ sheet.last_row, 15 ].min).each do |line|
        found = (sheet.first_column..sheet.last_column).filter_map do |col|
          date = to_date(sheet.cell(line, col))
          [ col, date ] if date
        end
        return [ line, found.to_h ] if found.size >= 3
      end
      nil
    end

    def to_date(value)
      case value
      when DateTime, Time then value.to_date
      when Date then value
      when String then Date.parse(value.strip) if value.strip.match?(DATE_PATTERN)
      end
    rescue Date::Error
      nil
    end

    def find_unit_column(sheet, date_row, name_col, date_columns)
      col = name_col + 1
      return nil if date_columns.key?(col) || col > sheet.last_column

      values = ((date_row + 1)..sheet.last_row).filter_map { |line| sheet.cell(line, col).to_s.strip.presence }
      return nil if values.empty?

      units = values.count { |v| UNITS.key?(v.downcase) }
      units.to_f / values.size >= 0.6 ? col : nil
    end

    def read_unit(sheet, line, unit_col, warnings)
      return nil unless unit_col

      raw = sheet.cell(line, unit_col).to_s.strip
      return nil if raw.empty?

      UNITS[raw.downcase] || (warnings << "unidade \"#{raw}\" não reconhecida; usei a do produto" and nil)
    end

    def title_of(sheet, date_row)
      (sheet.first_row..date_row).each do |line|
        (sheet.first_column..sheet.last_column).each do |col|
          text = sheet.cell(line, col)
          return text.to_s.strip if text.is_a?(String) && text.strip.present?
        end
      end
      nil
    end

    def parse_quantity(value, line, date, warnings, errors, unit)
      case value
      when nil then nil
      when Numeric then positive(BigDecimal(value.to_s))
      when String then parse_text(value.strip, line, date, warnings, errors, unit)
      else
        errors << cell_error(line, date, value)
        nil
      end
    end

    def parse_text(text, line, date, warnings, errors, unit)
      return nil if text.empty?

      with_unit = text.match(/\A(\d+(?:[.,]\d+)?)\s*([[:alpha:]ç.]+)\z/i)
      cell_unit = with_unit && UNITS[with_unit[2].downcase.delete(".")]
      return quantity_with_unit(BigDecimal(with_unit[1].tr(",", ".")), cell_unit, text, date, warnings, unit) if cell_unit

      normalized = text.tr(",", ".")
      if normalized.match?(/\A\d+(\.\d+)?\z/)
        warnings << "#{short(date)}: veio como texto \"#{text}\""
        positive(BigDecimal(normalized))
      elsif normalized.match?(/\A\d+(\.\d+)?(\s*\+\s*\d+(\.\d+)?)+\z/)
        total = normalized.split("+").sum { |part| BigDecimal(part.strip) }
        warnings << "#{short(date)}: \"#{text}\" somado como #{total.to_s('F').sub(/\.0\z/, '')}"
        positive(total)
      else
        errors << cell_error(line, date, text)
        nil
      end
    end

    # "60 Un" numa coluna de quantidade (R1.23, D11): o pedido guarda a unidade em que chegou. Na mesma unidade da linha,
    # o número entra com aviso; em outra, a célula fica de fora e o aviso pede para esclarecer com o cliente (R1.12).
    def quantity_with_unit(number, cell_unit, text, date, warnings, unit)
      if cell_unit == unit
        warnings << "#{short(date)}: veio como texto \"#{text}\""
        return positive(number)
      end

      line_unit = unit ? "a linha é em #{unit}" : "a linha não tem unidade"
      warnings << "#{short(date)}: \"#{text}\" está em #{cell_unit} e #{line_unit}; não entrou. Esclareça com o cliente."
      nil
    end

    def positive(number)
      number.positive? ? number : nil
    end

    def cell_error(line, date, value)
      "linha #{line}, #{short(date)}: \"#{value}\" não é um número"
    end

    def short(date)
      date.strftime("%d/%m")
    end
  end
end
