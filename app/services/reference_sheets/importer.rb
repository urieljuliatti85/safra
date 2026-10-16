module ReferenceSheets
  # Guarda as abas da semana escolhida de um ou mais arquivos (01, 02 e 03). O mesmo dia importado de novo troca as linhas
  # da comparação, e cada envio fica no histórico (SheetImport) com a versão de cada aba como estava.
  class Importer
    File = Data.define(:path, :filename)

    attr_reader :import

    def initialize(company:, user:, week_start:, files:)
      @company = company
      @user = user
      @dates = week_start..(week_start + 6)
      @files = files
    end

    # Devolve as ReferenceSheet gravadas, na ordem tipo e data. Arquivo ilegível levanta Reader::Unreadable.
    def call
      tabs = @files.flat_map do |file|
        Reader.new(file.path, extension: ::File.extname(file.filename)).call(@dates).map { |tab| [ tab, file.filename ] }
      end
      return [] if tabs.empty?

      ActsAsTenant.with_tenant(@company) do
        ReferenceSheet.transaction do
          @import = SheetImport.create!(user: @user, week_start: @dates.first, filenames: @files.map(&:filename))
          tabs.map { |tab, filename| save(tab, filename) }
        end
      end.uniq.sort_by { |sheet| [ sheet.kind, sheet.date ] }
    end

    private

    def save(tab, filename)
      sheet = ReferenceSheet.find_or_initialize_by(kind: tab.kind, date: tab.date)
      sheet.update!(filename: filename, tab_name: tab.name, imported_by: @user)
      sheet.lines.delete_all
      tab.lines.each_with_index do |line, index|
        sheet.lines.create!(section: line.section, label: line.label, quantity_text: line.quantity_text,
                            quantity: line.quantity, unit: line.unit, group_label: line.group_label, delivery_date: line.delivery_date,
                            position: index)
      end
      sheet.versions.create!(version: (sheet.versions.maximum(:version) || 0) + 1, sheet_import: @import, filename: filename,
                             tab_name: tab.name, imported_by: @user, lines: ReferenceSheetVersion.snapshot(tab.lines))
      sheet
    end
  end
end
