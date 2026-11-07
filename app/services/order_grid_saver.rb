# Grava a grade de pedidos de um cliente/semana.
# Entrada: { "<product_id>|<unit>" => { "2026-10-13" => "12,5", ... } }
# Quantidade vazia ou zero apaga a linha. Texto que não é número ("5 + 2") rejeita a gravação inteira.
# Todo salvamento que muda alguma coisa vira uma versão do pedido (OrderVersion), com o retrato inteiro.
class OrderGridSaver
  # measures_changed: a medida pedida de alguma linha mudou (D12), mesmo sem quantidade nova.
  Result = Data.define(:errors, :changed_dates, :measures_changed) do
    def initialize(errors:, changed_dates:, measures_changed: false) = super

    def ok?
      errors.empty?
    end
  end

  # source: de onde veio o salvamento (OrderVersion::SOURCES). import e restored_from só para registrar na versão.
  # measures: { "<product_id>|<unit>" => "10 mm" }, a medida pedida de cada linha da grade (R1.14, D12). Vazia apaga.
  # Prazo padrão de alteração (R1.26, D8). Restaurar versão e desfazer importação são correções e não pedem confirmação.
  ALTERATION_NOTICE = 48.hours
  CONFIRMED_SOURCES = %w[grid image import api].freeze

  # late_confirmed: a Hortifruti Modelo confirmou a alteração com menos de 48 h da entrega.
  def initialize(order:, quantities:, measures: {}, source: "grid", import: nil, restored_from: nil, late_confirmed: false)
    @late_confirmed = late_confirmed
    @order = order
    @quantities = quantities
    @measures = measures
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
    measures_changed = false
    Order.transaction do
      @order.lock!
      existing = @order.lines.to_a.group_by { |l| [ l.product_id, l.unit, l.delivery_date ] }
      before = existing.transform_values { |lines| lines.sum(&:quantity) }
      # Nada foi gravado ainda: sair aqui não deixa o pedido pela metade.
      outside = outside_week_errors(parsed, before)
      return Result.new(errors: outside, changed_dates: []) if outside.any?

      late = late_alterations(parsed, before)
      return Result.new(errors: late, changed_dates: []) if late.any? && !@late_confirmed

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
      measures_changed = save_measures
    end
    Result.new(errors: [], changed_dates: changed_dates.uniq.sort, measures_changed: measures_changed)
  end

  private

  # Mudar ou cancelar uma quantidade que já existia, com menos de 48 h da entrega (R1.26, D8). Produto novo no dia
  # (pedido extra) fica de fora até a pergunta A.5. As 48 h contam do início da janela de entrega do cliente
  # ("entrega a partir de"); sem horário cadastrado, da meia-noite do dia.
  def late_alterations(parsed, before)
    return [] unless CONFIRMED_SOURCES.include?(@source)

    from = @order.customer.delivery_from
    parsed.filter_map do |(product_id, unit, date), quantity|
      current = before.fetch([ product_id, unit, date ], 0)
      next if current.zero? || current == quantity

      delivery = date.in_time_zone.change(hour: from&.hour || 0, min: from&.min || 0)
      next if delivery - ALTERATION_NOTICE > Time.current

      "#{Product.find_by(id: product_id)&.name || 'Produto'} em #{Formatting.short_date(date)}: falta menos de 48 h para a entrega. " \
        "Marque \"A Hortifruti Modelo confirmou a alteração\" para gravar."
    end
  end

  # A medida vale para a linha inteira da grade (todos os dias do produto naquela unidade). Não gera versão do pedido.
  def save_measures
    @measures.to_h.sum do |key, text|
      product_id, unit = key.to_s.split("|", 2)
      measure = text.to_s.strip.first(100).presence
      stale = @order.lines.where(product_id: product_id, unit: unit).reject { |line| line.measure == measure }
      OrderLine.where(id: stale.map(&:id)).update_all(measure: measure)
    end.positive?
  end

  # A primeira versão de um pedido que já tinha linhas guarda como ele estava, para dar para voltar a ele.
  def record_version(before, changes)
    next_version = @order.versions.maximum(:version).to_i
    if next_version.zero? && before.values.any?(&:positive?)
      create_version(next_version += 1, "initial", snapshot(before), [], actor: false)
    end
    after = @order.lines.reload.group(:product_id, :unit, :delivery_date).sum(:quantity)
    create_version(next_version + 1, @source, snapshot(after), changes_list(changes), late_confirmed: @late_confirmed)
    # Sem data de chegada informada, o pedido conta como recebido no primeiro salvamento (D7); quem lança pode corrigir.
    @order.update!(received_at: Time.current) if @order.received_at.nil?
  end

  def create_version(number, source, lines, changes, actor: true, late_confirmed: false)
    user = Current.user if actor
    @order.versions.create!(
      version: number, source: source, lines: lines, changes_list: changes, late_confirmed: late_confirmed,
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
    @products = Product.where(id: @quantities.keys.map { |k| k.split("|").first }).index_by(&:id)
    @quantities.each_with_object({}) do |(key, cells), parsed|
      product_id, unit = key.split("|")
      product = @products[product_id.to_i]
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

  # Os dias que a grade mostra. Criar ou mudar quantidade fora deles deixaria a linha invisível em toda grade.
  # Zero continua valendo, para apagar; e linha antiga que chega igual passa, para restaurar versão de um pedido
  # que já tinha uma dessas continuar funcionando.
  def outside_week_errors(parsed, before)
    week = @order.week_dates
    parsed.filter_map do |(product_id, unit, date), quantity|
      next if week.cover?(date) || quantity.zero? || before.fetch([ product_id, unit, date ], 0) == quantity

      "#{@products[product_id]&.name || 'Produto'} em #{Formatting.short_date(date)}: fora da semana do pedido " \
        "(#{Formatting.short_date(week.first)} a #{Formatting.short_date(week.last)})."
    end
  end

  def parse_quantity(text)
    value = text.to_s.strip.tr(",", ".")
    return BigDecimal("0") if value.empty?
    return nil unless value.match?(/\A\d+(\.\d{1,3})?\z/)

    BigDecimal(value)
  end
end
