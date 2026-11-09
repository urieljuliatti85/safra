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
    def initialize(import:, mappings:, late_confirmed: false)
      @late_confirmed = late_confirmed
      @import = import
      @mappings = mappings
    end

    def call
      return Result.new(errors: [ "Esta planilha já foi aplicada." ], changed_dates: []) if @import.applied?
      return Result.new(errors: @import.errors_list, changed_dates: []) if @import.errors_list.any?

      chosen, errors = choose_products
      return Result.new(errors: errors, changed_dates: []) if errors.any?

      order = Order.find_or_create_by!(customer: @import.customer, week_start: @import.week_start)
      after = grid(chosen)
      before = snapshot(order, after)
      saved = nil
      OrderImport.transaction do
        saved = OrderGridSaver.new(order: order, quantities: after, source: "import", import: @import, late_confirmed: @late_confirmed,
                                   entry_type: @import.entry_type).call
        raise ActiveRecord::Rollback unless saved.ok?

        aliases = remember_names(chosen)
        # No extra a planilha traz o acréscimo; o desfazer compara com o total que ficou gravado.
        after = snapshot(order, after) if @import.extra?
        @import.update!(status: "applied", applied_at: Time.current,
                        payload: @import.payload.merge("undo" => { "before" => before, "after" => after, "aliases" => aliases }))
      end
      return Result.new(errors: saved.errors, changed_dates: []) unless saved.ok?

      Result.new(errors: [], changed_dates: saved.changed_dates)
    end

    # ["Cenoura ralada em 14/10", ...]: o que a importação pediria de confirmação das 48 h, com os produtos já
    # reconhecidos. Linha sem produto fica de fora até alguém escolher; se virar alteração, o aplicar recusa e avisa.
    def late_alterations
      order = Order.find_by(customer: @import.customer, week_start: @import.week_start)
      return [] unless order

      chosen, = choose_products
      OrderGridSaver.new(order: order, quantities: grid(chosen), source: "import", entry_type: @import.entry_type).late_alterations_preview
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

    # O pedido de hoje nas mesmas células que a importação vai gravar, para o Undoer devolver.
    def snapshot(order, after)
      current = order.lines.group(:product_id, :unit, :delivery_date).sum(:quantity)
      after.to_h do |key, cells|
        product_id, unit = key.split("|")
        [ key, cells.to_h { |date, _| [ date, current[[ product_id.to_i, unit, Date.iso8601(date) ]]&.to_s("F")&.sub(/\.0\z/, "").to_s ] } ]
      end
    end

    # Devolve os apelidos que mudaram: [{ "name", "product_id", "previous_product_id" }], para o Undoer.
    def remember_names(chosen)
      chosen.each_with_object({}) do |(row, product), changed|
        record = CustomerAlias.find_or_initialize_by(customer: @import.customer, name_in_order: row["name"])
        next if record.persisted? && record.product_id == product.id

        changed[row["name"]] ||= { "name" => row["name"], "previous_product_id" => record.product_id }
        changed[row["name"]]["product_id"] = product.id
        record.update!(product: product)
      end.values
    end
  end
end
