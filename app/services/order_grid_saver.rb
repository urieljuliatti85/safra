# Grava a grade de pedidos de um cliente/semana.
# Entrada: { "<product_id>|<unit>" => { "2026-10-13" => "12,5", ... } }
# Quantidade vazia ou zero apaga a linha. Texto que não é número ("5 + 2") rejeita a gravação inteira.
# Todo salvamento que muda alguma coisa vira uma versão do pedido (OrderVersion), com o retrato inteiro.
class OrderGridSaver
  Result = Data.define(:errors, :changed_dates) do
    def ok?
      errors.empty?
    end
  end

  # source: de onde veio o salvamento (OrderVersion::SOURCES). import e restored_from só para registrar na versão.
  def initialize(order:, quantities:, source: "grid", import: nil, restored_from: nil)
    @order = order
    @quantities = quantities
    @source = source
    @import = import
    @restored_from = restored_from
  end

  def call
    errors = []
    parsed = parse(errors)
    return Result.new(errors: errors, changed_dates: []) unless errors.empty?

    changed_dates = []
    changes = []
    Order.transaction do
      @order.lock!
      existing = @order.lines.to_a.group_by { |l| [ l.product_id, l.unit, l.delivery_date ] }
      before = existing.transform_values { |lines| lines.sum(&:quantity) }
      parsed.each do |(product_id, unit, date), quantity|
        lines = existing.fetch([ product_id, unit, date ], [])
        current = lines.sum(&:quantity)
        next if current == quantity

        changed_dates << date
        changes << [ product_id, unit, date, current, quantity ]
        lines.drop(1).each(&:destroy!)
        if quantity.zero?
          lines.first&.destroy!
        elsif lines.first
          lines.first.update!(quantity: quantity)
        else
          @order.lines.create!(product_id: product_id, unit: unit, delivery_date: date, quantity: quantity)
        end
      end
      record_version(before, changes) if changes.any?
    end
    Result.new(errors: [], changed_dates: changed_dates.uniq.sort)
  end

  private

  # A primeira versão de um pedido que já tinha linhas guarda como ele estava, para dar para voltar a ele.
  def record_version(before, changes)
    next_version = @order.versions.maximum(:version).to_i
    if next_version.zero? && before.values.any?(&:positive?)
      create_version(next_version += 1, "initial", snapshot(before), [], actor: false)
    end
    after = @order.lines.reload.group(:product_id, :unit, :delivery_date).sum(:quantity)
    create_version(next_version + 1, @source, snapshot(after), changes_list(changes))
  end

  def create_version(number, source, lines, changes, actor: true)
    user = Current.user if actor
    @order.versions.create!(
      version: number, source: source, lines: lines, changes_list: changes,
      user: user, user_name: actor ? (user&.name || (Current.api_token && "API: #{Current.api_token.name}")) : nil,
      order_import: actor ? @import : nil, restored_from_version: actor ? @restored_from : nil
    )
  end

  def snapshot(quantities)
    quantities.select { |_, quantity| quantity.positive? }.sort_by { |(product_id, unit, date), _| [ date, product_id, unit ] }
              .map { |(product_id, unit, date), quantity| { "product_id" => product_id, "unit" => unit, "date" => date.iso8601, "quantity" => text(quantity) } }
  end

  def changes_list(changes)
    names = Product.where(id: changes.map(&:first)).pluck(:id, :name).to_h
    changes.sort_by { |product_id, unit, date, _, _| [ names[product_id].to_s, unit, date ] }.map do |product_id, unit, date, before, after|
      { "product_id" => product_id, "product" => names[product_id], "unit" => unit, "date" => date.iso8601,
        "before" => before.positive? ? text(before) : nil, "after" => after.positive? ? text(after) : nil }
    end
  end

  def text(quantity)
    quantity.to_s("F").sub(/\.0\z/, "")
  end

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
        elsif quantity >= OrderLine::MAX_QUANTITY
          errors << "#{product&.name || 'Produto'} em #{Formatting.short_date(date)}: #{text} é grande demais. Confira a quantidade."
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
