# Conferência de quantidades, unidades e datas. Gera alertas (nunca erros) a partir dos pedidos.
# Referência: função alertas() de prototipo/safra.html.
class ConferenceChecker
  Alert = Data.define(:level, :kind, :message) # level: :warn | :mute

  FACTOR_NOTE = /1,3|copiad|50 ou 25/

  def initialize(company:)
    @company = company
  end

  def call
    ActsAsTenant.with_tenant(@company) do
      lines = OrderLine.where("quantity > 0").includes(:order, product: [ :cut, { raw_material: :supplier } ])
      alerts = line_note_alerts(lines) + missing_factor_alerts(lines) + unit_alerts(lines) +
               supplier_alerts(lines) + factor_note_alerts(lines) + uncovered_alerts + sunday_alerts(lines)
      alerts.sort_by { |a| [ a.level == :warn ? 0 : 1, a.kind ] }
    end
  end

  private

  # Uma linha por cliente, produto e observação, com todas as datas afetadas.
  def line_note_alerts(lines)
    lines.select { |l| l.note.present? }.group_by { |l| [ l.order.customer, l.product, l.note ] }.map do |(customer, product, note), group|
      dates = group.map(&:delivery_date).uniq.sort.map { |d| Formatting.short_date(d) }.join(", ")
      Alert.new(:warn, "Pedido", "#{customer.short_name}: #{product.name} (#{dates}). #{note}.")
    end
  end

  def missing_factor_alerts(lines)
    lines.reject { |l| l.product.raw? || l.product.raw_material.multiply_factor }
         .group_by { |l| l.product.raw_material }.map do |raw_material, group|
      names = group.map { |l| l.product.name }.uniq.sort.join(", ")
      Alert.new(:warn, "Sem fator", "#{raw_material.name}: sem fator de conversão, então a compra não é calculada (#{names}).")
    end
  end

  def unit_alerts(lines)
    lines.group_by { |l| [ l.product.raw_material, l.product.product_group ] }.filter_map do |(raw_material, _), group|
      units = group.map(&:unit).uniq
      next if units.size < 2

      Alert.new(:warn, "Unidade", "#{raw_material.name}: pedido em unidades diferentes (#{units.sort.join(' e ')}). Não dá para somar sem converter.")
    end
  end

  def supplier_alerts(lines)
    names = lines.map { |l| l.product.raw_material }.uniq.select { |rm| rm.supplier.nil? }.map(&:name).sort
    return [] if names.empty?

    [ Alert.new(:mute, "Fornecedor", "Sem fornecedor cadastrado: #{names.join(', ')}.") ]
  end

  def factor_note_alerts(lines)
    lines.map { |l| l.product.raw_material }.uniq.select { |rm| rm.note.to_s.match?(FACTOR_NOTE) }.map do |rm|
      Alert.new(:mute, "Fator", "#{rm.name}: #{rm.note}.")
    end
  end

  # Linhas cuja produção cai antes da primeira compra cadastrada: não entram em nenhuma compra.
  def uncovered_alerts
    uncovered = PurchasePlanner.new(company: @company).call.uncovered
    return [] if uncovered.empty?

    dates = uncovered.map(&:delivery_date).uniq.sort.map { |d| Formatting.short_date(d) }.join(", ")
    [ Alert.new(:mute, "Compra", "#{uncovered.size} linhas de pedido (entregas em #{dates}) são produzidas antes da primeira compra cadastrada e não entram em nenhuma compra.") ]
  end

  def sunday_alerts(lines)
    sundays = lines.select { |l| l.delivery_date.sunday? }
    return [] if sundays.empty?

    [ Alert.new(:mute, "Data", "#{sundays.size} linhas com entrega no domingo. Domingo não tem produção: ela cai para sábado.") ]
  end
end
