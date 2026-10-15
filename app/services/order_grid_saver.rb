# Grava a grade de pedidos de um cliente/semana.
# Entrada: { "<product_id>|<unit>" => { "2026-10-13" => "12,5", ... } }
# Quantidade vazia ou zero apaga a linha. Texto que não é número ("5 + 2") rejeita a gravação inteira.
class OrderGridSaver
  Result = Data.define(:errors, :changed_dates) do
    def ok?
      errors.empty?
    end
  end

  def initialize(order:, quantities:)
    @order = order
    @quantities = quantities
  end

  def call
    errors = []
    parsed = parse(errors)
    return Result.new(errors: errors, changed_dates: []) unless errors.empty?

    changed_dates = []
    Order.transaction do
      existing = @order.lines.to_a.group_by { |l| [ l.product_id, l.unit, l.delivery_date ] }
      parsed.each do |(product_id, unit, date), quantity|
        lines = existing.fetch([ product_id, unit, date ], [])
        current = lines.sum(&:quantity)
        next if current == quantity

        changed_dates << date
        lines.drop(1).each(&:destroy!)
        if quantity.zero?
          lines.first&.destroy!
        elsif lines.first
          lines.first.update!(quantity: quantity)
        else
          @order.lines.create!(product_id: product_id, unit: unit, delivery_date: date, quantity: quantity)
        end
      end
    end
    Result.new(errors: [], changed_dates: changed_dates.uniq.sort)
  end

  private

  def parse(errors)
    products = Product.where(id: @quantities.keys.map { |k| k.split("|").first }).index_by(&:id)
    @quantities.each_with_object({}) do |(key, cells), parsed|
      product_id, unit = key.split("|")
      product = products[product_id.to_i]
      cells.each do |date_text, text|
        date = Date.iso8601(date_text)
        quantity = parse_quantity(text)
        if quantity.nil?
          errors << "#{product&.name || 'Produto'} em #{Formatting.short_date(date)}: \"#{text}\" não é um número."
        else
          parsed[[ product_id.to_i, unit, date ]] = quantity
        end
      end
    end
  rescue Date::Error
    errors << "Data inválida na grade."
    {}
  end

  def parse_quantity(text)
    value = text.to_s.strip.tr(",", ".")
    return BigDecimal("0") if value.empty?
    return nil unless value.match?(/\A\d+(\.\d{1,3})?\z/)

    BigDecimal(value)
  end
end
