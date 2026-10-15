module OrderImports
  # O que a importação mudaria no pedido: por linha do arquivo e por dia, quantidade nova × a de hoje.
  class Preview
    Cell = Data.define(:date, :new_quantity, :current, :status) # status: :same | :new | :changed | :removed | :empty
    Line = Data.define(:index, :row, :product, :unit, :cells, :warnings)

    def initialize(import)
      @import = import
      @products = Product.where(id: import.rows.filter_map { |r| r["product_id"] }).index_by(&:id)
      @current = current_quantities
    end

    def lines
      @lines ||= @import.rows.each_with_index.map do |row, index|
        product = @products[row["product_id"]]
        unit = row["unit"] || product&.unit
        cells = @import.dates.map { |date| cell(row, product, unit, date) }
        Line.new(index: index, row: row, product: product, unit: unit, cells: cells, warnings: row["warnings"])
      end
    end

    def counts
      cells = lines.flat_map(&:cells)
      { new: cells.count { |c| c.status == :new }, changed: cells.count { |c| c.status == :changed },
        removed: cells.count { |c| c.status == :removed }, unmatched: lines.count { |l| l.product.nil? } }
    end

    private

    def cell(row, product, unit, date)
      text = row["quantities"][date.iso8601]
      new_quantity = text && BigDecimal(text)
      current = product ? @current.fetch([ product.id, unit, date ], nil) : nil
      status = if new_quantity.nil? && current.nil? then :empty
      elsif new_quantity.nil? then :removed
      elsif current.nil? then :new
      elsif current == new_quantity then :same
      else :changed
      end
      Cell.new(date: date, new_quantity: new_quantity, current: current, status: status)
    end

    def current_quantities
      order = Order.find_by(customer: @import.customer, week_start: @import.week_start)
      return {} unless order

      order.lines.group(:product_id, :unit, :delivery_date).sum(:quantity)
           .transform_keys { |product_id, unit, date| [ product_id, unit, date ] }
    end
  end
end
