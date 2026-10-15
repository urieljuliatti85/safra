module OrderImports
  # Grava o que o usuário conferiu: reconhece de vez os nomes novos (apelido) e atualiza o pedido da semana.
  # A planilha manda nos produtos que ela traz: célula vazia numa linha com outras quantidades apaga a linha.
  class Applier
    Result = Data.define(:errors, :changed_dates) do
      def ok?
        errors.empty?
      end
    end

    # mappings: { "0" => "<product_id>" | "ignore", ... } pelo índice da linha no payload.
    def initialize(import:, mappings:)
      @import = import
      @mappings = mappings
    end

    def call
      return Result.new(errors: [ "Esta planilha já foi aplicada." ], changed_dates: []) if @import.applied?
      return Result.new(errors: @import.errors_list, changed_dates: []) if @import.errors_list.any?

      chosen, errors = choose_products
      return Result.new(errors: errors, changed_dates: []) if errors.any?

      order = Order.find_or_create_by!(customer: @import.customer, week_start: @import.week_start)
      saved = OrderGridSaver.new(order: order, quantities: grid(chosen)).call
      return Result.new(errors: saved.errors, changed_dates: []) unless saved.ok?

      OrderImport.transaction do
        remember_names(chosen)
        @import.update!(status: "applied", applied_at: Time.current)
      end
      Result.new(errors: [], changed_dates: saved.changed_dates)
    end

    private

    # [[row, product], ...] das linhas não ignoradas; erro quando falta escolher o produto.
    def choose_products
      products = Product.where(id: @mappings.values.reject { |v| v == "ignore" }).index_by { |p| p.id.to_s }
      errors = []
      chosen = @import.rows.each_with_index.filter_map do |row, index|
        choice = @mappings[index.to_s].presence || row["product_id"]&.to_s
        next if choice == "ignore"

        product = products[choice.to_s] || (Product.find_by(id: choice) if choice)
        if product.nil?
          errors << "Linha #{row['line']} (\"#{row['name']}\"): escolha o produto ou ignore a linha."
          next
        end
        [ row, product ]
      end
      [ chosen, errors ]
    end

    # { "<product_id>|<unit>" => { "2026-10-13" => "7" } }, somando linhas do arquivo que viram o mesmo produto.
    def grid(chosen)
      chosen.each_with_object({}) do |(row, product), grid|
        cells = (grid["#{product.id}|#{row['unit'] || product.unit}"] ||= @import.dates.to_h { |d| [ d.iso8601, "" ] })
        row["quantities"].each do |date, text|
          next if text.nil?

          cells[date] = (BigDecimal(cells[date].presence || "0") + BigDecimal(text)).to_s("F").sub(/\.0\z/, "")
        end
      end
    end

    def remember_names(chosen)
      chosen.each do |row, product|
        record = CustomerAlias.find_or_initialize_by(customer: @import.customer, name_in_order: row["name"])
        record.update!(product: product) unless record.persisted? && record.product_id == product.id
      end
    end
  end
end
