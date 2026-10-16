module ReferenceSheets
  # Guarda as abas da semana escolhida de um ou mais arquivos (02 e 03). O mesmo dia importado de novo troca as linhas.
  class Importer
    File = Data.define(:path, :filename)

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
      ActsAsTenant.with_tenant(@company) do
        ReferenceSheet.transaction { tabs.map { |tab, filename| save(tab, filename) } }
      end.uniq.sort_by { |sheet| [ sheet.kind, sheet.date ] }
    end

    private

    def save(tab, filename)
      sheet = ReferenceSheet.find_or_initialize_by(kind: tab.kind, date: tab.date)
      sheet.update!(filename: filename, tab_name: tab.name, imported_by: @user)
      sheet.lines.delete_all
      tab.lines.each_with_index do |line, index|
        sheet.lines.create!(section: line.section, label: line.label, quantity_text: line.quantity_text,
                            quantity: line.quantity, unit: line.unit, position: index)
      end
      sheet
    end
  end
end
