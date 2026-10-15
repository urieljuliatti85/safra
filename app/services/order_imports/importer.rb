module OrderImports
  # Lê o arquivo, reconhece os produtos e guarda tudo num OrderImport para o usuário conferir antes de aplicar.
  class Importer
    def initialize(company:, customer:, path:, filename:)
      @company = company
      @customer = customer
      @path = path
      @filename = filename
    end

    def call
      ActsAsTenant.with_tenant(@company) do
        result = SheetReader.new(@path, extension: File.extname(@filename)).call
        matcher = Matcher.new(customer: @customer)
        rows = result.rows.map { |row| serialize(row, matcher.call(row.name)) }
        OrderImport.create!(
          customer: @customer, filename: @filename, week_start: result.dates.min.beginning_of_week,
          payload: {
            sheet: result.sheet, title: result.title, dates: result.dates.map(&:iso8601), rows: rows,
            errors: result.errors, ignored_blank: result.ignored_blank, customer_warning: customer_warning(result.title)
          }
        )
      end
    end

    private

    def serialize(row, match)
      {
        line: row.line, name: row.name, unit: row.unit, warnings: row.warnings,
        quantities: row.quantities.to_h { |date, qty| [ date.iso8601, qty&.to_s("F")&.sub(/\.0\z/, "") ] },
        product_id: match&.product&.id, matched_by: match&.by
      }
    end

    # O título da planilha costuma dizer de que cliente ela é; avisa se parece outro.
    def customer_warning(title)
      return nil if title.blank?

      normalized = NameNormalizer.call(title)
      guess = Customer.all.find { |c| normalized.include?(NameNormalizer.call(c.name)) }
      return nil if guess.nil? || guess == @customer

      "O título da planilha (\"#{title}\") parece ser de #{guess.name}, mas você escolheu #{@customer.name}."
    end
  end
end
