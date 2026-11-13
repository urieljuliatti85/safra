module OrderImports
  # Desfaz uma importação: devolve o pedido ao que era antes nos produtos e dias que ela tocou e reabre a importação.
  # - Planilha: pelo retrato gravado ao aplicar; apaga os apelidos que ela criou (ou volta o produto dos que ela trocou).
  # - Pedido em imagem: pelo que foi digitado a partir dela, lido das versões do pedido desde o último desfazer; a
  #   imagem volta a "pendente". Resolve "lancei na semana errada": desfaz, troca a semana e digita de novo.
  # - PDF de AFs: pelas versões que ele gravou em cada semana; cada AF volta ao que era (a nova sai, a alteração volta à
  #   lista anterior) e o número da AF de cada linha volta pelo retrato gravado ao aplicar (`af_lines`). PDF aplicado
  #   antes desse retrato existir não é desfeito: sem ele, a próxima alteração da AF não acharia as linhas dela.
  # Programação, produção e compras são calculadas do pedido e voltam sozinhas. Versões já enviadas aos setores ficam
  # como estão: a tela mostra a diferença e o reenvio é com o usuário. Desfazer não pede a confirmação das 48 h (D8).
  class Undoer
    Edit = Data.define(:product, :unit, :date, :imported, :current)
    Result = Data.define(:errors, :changed_dates) do
      def ok?
        errors.empty?
      end
    end

    def initialize(import:)
      @import = import
    end

    def undoable?
      if @import.image?
        cells.any? { |order, by_key| differs_from_before?(order, by_key) }
      else
        @import.applied? && snapshot.present? && (!@import.af? || snapshot.key?("af_lines"))
      end
    end

    # Células que mudaram no pedido depois da importação: desfazer passa por cima delas.
    def later_edits
      return [] unless undoable?

      products = Product.where(id: cells.values.flat_map(&:keys).map { |key| key.split("|").first }).index_by(&:id)
      cells.flat_map do |order, by_key|
        current = current_quantities(order)
        by_key.flat_map do |key, by_date|
          product_id, unit = key.split("|")
          by_date.filter_map do |date, (_, after)|
            imported = quantity(after)
            now = current.fetch([ product_id.to_i, unit, Date.iso8601(date) ], BigDecimal("0"))
            next if imported == now

            Edit.new(product: products[product_id.to_i], unit: unit, date: Date.iso8601(date), imported: imported, current: now)
          end
        end
      end.sort_by(&:date)
    end

    # Dias com produção ou compra enviada que, depois de desfazer, ficariam diferentes da versão enviada.
    # Simula dentro de uma transação que é sempre desfeita.
    def stale_after_undo
      return { production: [], purchase: [] } unless undoable?

      stale = nil
      ActiveRecord::Base.transaction do
        stale = { production: StalePlans.dates(@import.company), purchase: StalePlans.purchase_dates(@import.company) } if restore.ok?
        raise ActiveRecord::Rollback
      end
      @import.reload
      reset
      stale || { production: [], purchase: [] }
    end

    def call
      result = nil
      OrderImport.transaction do
        # Duplo clique ou F5: a segunda chamada espera a primeira e já encontra a importação desfeita.
        @import.lock!
        reset
        unless undoable?
          result = Result.new(errors: [ "Esta importação não pode ser desfeita." ], changed_dates: [])
          next
        end

        result = restore
        raise ActiveRecord::Rollback unless result.ok?
      end
      result
    end

    private

    def reset
      @cells = nil
      @current = nil
    end

    def snapshot
      @import.payload["undo"]
    end

    # { order => { "<product_id>|<unit>" => { "2026-10-13" => [antes, depois] } } }, em texto ("" quando não havia).
    def cells
      @cells ||= @import.image? || @import.af? ? cells_from_versions : cells_from_snapshot
    end

    def cells_from_snapshot
      order = Order.find_or_create_by!(customer: @import.customer, week_start: @import.week_start)
      by_key = snapshot["before"].to_h do |key, dates|
        [ key, dates.to_h { |date, before| [ date, [ before, snapshot.dig("after", key, date) ] ] } ]
      end
      { order => by_key }
    end

    # Versões gravadas por esta importação depois do último desfazer: o antes da primeira e o depois da última, por célula.
    def cells_from_versions
      versions = OrderVersion.where(order_import: @import).includes(:order).order(:id).to_a
      last_undo = versions.rindex { |version| version.source == "undo" }
      versions = versions.drop(last_undo + 1) if last_undo

      versions.each_with_object({}) do |version, cells|
        version.changes_list.each do |change|
          by_date = ((cells[version.order] ||= {})["#{change['product_id']}|#{change['unit']}"] ||= {})
          (by_date[change["date"]] ||= [ change["before"].to_s, nil ])[1] = change["after"].to_s
        end
      end
    end

    def differs_from_before?(order, by_key)
      current = current_quantities(order)
      by_key.any? do |key, by_date|
        product_id, unit = key.split("|")
        by_date.any? { |date, (before, _)| current.fetch([ product_id.to_i, unit, Date.iso8601(date) ], BigDecimal("0")) != quantity(before) }
      end
    end

    def restore
      changed_dates = []
      cells.each do |order, by_key|
        before = by_key.transform_values { |by_date| by_date.transform_values(&:first) }
        saved = OrderGridSaver.new(order: order, quantities: before, source: "undo", import: @import).call
        return Result.new(errors: saved.errors, changed_dates: []) unless saved.ok?

        changed_dates.concat(saved.changed_dates)
      end

      restore_af_numbers if @import.af?
      restore_aliases unless @import.image? || @import.af?
      @import.update!(status: "pending", applied_at: nil, payload: @import.payload.except("undo"))
      Result.new(errors: [], changed_dates: changed_dates.uniq.sort)
    end

    # O número da AF de cada linha que o PDF tocou volta ao que era (AfApplier grava o retrato ao aplicar).
    def restore_af_numbers
      orders = Order.where(customer: @import.customer, week_start: snapshot["af_lines"].map { |line| line["week"] }.uniq).index_by { |o| o.week_start.iso8601 }
      snapshot["af_lines"].each do |line|
        order = orders[line["week"]] or next
        order.lines.where(product_id: line["product_id"], unit: line["unit"], delivery_date: line["date"]).update_all(af_number: line["af_number"])
      end
    end

    # Só mexe no apelido se ele ainda aponta para o produto que a importação gravou.
    def restore_aliases
      snapshot["aliases"].each do |entry|
        record = CustomerAlias.find_by(customer: @import.customer, name_in_order: entry["name"])
        next if record.nil? || record.product_id != entry["product_id"]

        if entry["previous_product_id"] && Product.exists?(entry["previous_product_id"])
          record.update!(product_id: entry["previous_product_id"])
        else
          record.destroy!
        end
      end
    end

    def current_quantities(order)
      (@current ||= {})[order.id] ||= order.lines.group(:product_id, :unit, :delivery_date).sum(:quantity)
    end

    def quantity(text)
      text.present? ? BigDecimal(text) : BigDecimal("0")
    end
  end
end
