require "roo"
require "roo-xls"

module ReferenceSheets
  # Lê as planilhas feitas à mão, uma aba por dia ("TERÇA 13-10-26"):
  # - 02 - PLANILHA DE PRODUÇÃO: blocos lado a lado com o título no cabeçalho (DESCASCADOR | CX, APRONTES | CX,
  #   CORTES MANUAIS | KG, CORTES | KG); em cada bloco, o nome numa coluna e a quantidade na seguinte.
  # - 03 - COMPRAS CEASA: título "PEDIDOS ...", depois matéria-prima e quantidade em texto ("20 CX", "500 Gr").
  # Só lê as abas dos dias pedidos. Linhas sem quantidade (instruções, separadores, "1ª ETAPA") ficam de fora.
  class Reader
    Line = Data.define(:section, :label, :quantity_text, :quantity, :unit)
    Tab = Data.define(:name, :kind, :date, :lines)

    class Unreadable < StandardError; end

    TAB_DATE = /(\d{1,2})-(\d{1,2})-(\d{2,4})/
    SECTIONS = { "DESCASCADOR" => "descascador", "APRONTES" => "aprontes", "CORTES" => "cortes" }.freeze
    UNITS = { "cx" => "cx", "caixa" => "cx", "caixas" => "cx", "sc" => "sc", "saco" => "sc", "sacos" => "sc", "kg" => "kg",
              "g" => "g", "gr" => "g", "un" => "un", "und" => "un", "unid" => "un" }.freeze
    QUANTITY = /\A\s*(\d+(?:[.,]\d+)?)\s*([[:alpha:]]+)?\.?\s*\z/
    NOT_ITEM = /\A\s*(\(|-|\d+ª\s+ETAPA|MARCADOR)|\/\//i

    def initialize(path, extension: nil)
      @path = path
      @extension = extension.to_s.delete_prefix(".").downcase.presence&.to_sym
    end

    def call(dates)
      book = open_book
      book.sheets.filter_map do |name|
        date = tab_date(name)
        next unless date && dates.cover?(date)

        read_tab(book.sheet(name), name, date)
      end
    end

    private

    def open_book
      @extension ? Roo::Spreadsheet.open(@path, extension: @extension) : Roo::Spreadsheet.open(@path)
    rescue StandardError => e
      raise Unreadable, "Não consegui abrir o arquivo (#{e.message.truncate(80)}). Envie ods, xlsx ou xls."
    end

    def tab_date(name)
      match = name.to_s.match(TAB_DATE) or return nil
      day, month, year = match.captures.map(&:to_i)
      Date.new(year < 100 ? 2000 + year : year, month, day)
    rescue Date::Error
      nil
    end

    def read_tab(sheet, name, date)
      return nil if sheet.last_row.nil?

      rows = (sheet.first_row..sheet.last_row).map { |index| sheet.row(index) }
      if rows.first(8).flatten.any? { |cell| text(cell).upcase.include?("PLANILHA DE PRODU") }
        Tab.new(name: name, kind: "production", date: date, lines: production_lines(rows))
      elsif rows.first(3).any? { |row| text(row.first).upcase.start_with?("PEDIDOS") }
        Tab.new(name: name, kind: "purchase", date: date, lines: purchase_lines(rows))
      end
    end

    # Acha a linha de cabeçalho com os blocos e lê cada bloco de cima a baixo.
    def production_lines(rows)
      header_index = rows.index { |row| row.any? { |cell| section_for(cell) } } or return []
      blocks = rows[header_index].each_with_index.filter_map do |cell, column|
        section = section_for(cell) or next
        [ section, column, unit_for(rows[header_index][column + 1]) ]
      end
      blocks.flat_map do |section, column, unit|
        rows.drop(header_index + 1).filter_map { |row| line(section, row[column], row[column + 1], unit) }
      end
    end

    def purchase_lines(rows)
      start = rows.index { |row| text(row.first).upcase.start_with?("PEDIDOS") }
      rows.drop(start + 1).filter_map { |row| line("compras", row[0], row[1], nil) }
    end

    def line(section, name_cell, quantity_cell, default_unit)
      label = text(name_cell).squish
      return nil if label.empty? || label.match?(NOT_ITEM) || blank?(quantity_cell)

      quantity, unit = quantity_of(quantity_cell, default_unit)
      Line.new(section: section, label: label, quantity_text: text(quantity_cell).squish, quantity: quantity, unit: unit)
    end

    def quantity_of(cell, default_unit)
      return [ BigDecimal(cell.to_s), default_unit ] if cell.is_a?(Numeric)

      match = text(cell).match(QUANTITY) or return [ nil, nil ]
      unit = match[2] ? UNITS[match[2].downcase] : default_unit
      return [ nil, nil ] if match[2] && unit.nil?

      [ BigDecimal(match[1].tr(",", ".")), unit ]
    end

    def section_for(cell)
      SECTIONS.find { |title, _| text(cell).upcase.squish.start_with?(title) }&.last
    end

    def unit_for(cell) = UNITS[text(cell).downcase.squish]

    def blank?(cell) = cell.nil? || text(cell).strip.empty?

    def text(cell) = cell.to_s
  end
end
