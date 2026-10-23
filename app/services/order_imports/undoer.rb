module OrderImports
  # Desfaz uma planilha aplicada: devolve o pedido ao que era antes nos produtos e dias que ela tocou,
  # apaga os apelidos que ela criou (ou volta o produto dos que ela trocou) e reabre a importação.
  # Programação, produção e compras são calculadas do pedido e voltam sozinhas. Versões já enviadas
  # aos setores ficam como estão: a tela mostra a diferença e o reenvio é com o usuário.
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
      @import.applied? && snapshot.present?
    end

    # Células que mudaram no pedido depois da importação: desfazer passa por cima delas.
    def later_edits
      return [] unless undoable?

      current = current_quantities
      products = Product.where(id: snapshot["after"].keys.map { |key| key.split("|").first }).index_by(&:id)
      snapshot["after"].flat_map do |key, cells|
        product_id, unit = key.split("|")
        cells.filter_map do |date, text|
          imported = quantity(text)
          now = current.fetch([ product_id.to_i, unit, Date.iso8601(date) ], BigDecimal("0"))
          next if imported == now

          Edit.new(product: products[product_id.to_i], unit: unit, date: Date.iso8601(date), imported: imported, current: now)
        end
      end
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
      stale || { production: [], purchase: [] }
    end

    def call
      return Result.new(errors: [ "Esta importação não pode ser desfeita." ], changed_dates: []) unless undoable?

      result = nil
      OrderImport.transaction do
        result = restore
        raise ActiveRecord::Rollback unless result.ok?
      end
      result
    end

    private

    def snapshot
      @import.payload["undo"]
    end

    def restore
      order = Order.find_or_create_by!(customer: @import.customer, week_start: @import.week_start)
      saved = OrderGridSaver.new(order: order, quantities: snapshot["before"]).call
      return Result.new(errors: saved.errors, changed_dates: []) unless saved.ok?

      restore_aliases
      @import.update!(status: "pending", applied_at: nil, payload: @import.payload.except("undo"))
      Result.new(errors: [], changed_dates: saved.changed_dates)
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

    def current_quantities
      order = Order.find_by(customer: @import.customer, week_start: @import.week_start)
      return {} unless order

      order.lines.group(:product_id, :unit, :delivery_date).sum(:quantity)
    end

    def quantity(text)
      text.present? ? BigDecimal(text) : BigDecimal("0")
    end
  end
end
