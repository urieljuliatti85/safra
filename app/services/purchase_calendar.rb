# Dias de compra na CEASA (esteira simplificada, passo 3): os dias da semana cadastrados na empresa, segunda e quinta
# por padrão. Cada compra abastece a produção do dia dela até a véspera da compra seguinte (PurchasePlanner).
class PurchaseCalendar
  WEEKDAYS = { 1 => "Seg", 2 => "Ter", 3 => "Qua", 4 => "Qui", 5 => "Sex", 6 => "Sáb", 0 => "Dom" }.freeze

  def initialize(company)
    @weekdays = company.purchase_weekdays.map(&:to_i)
  end

  def purchase_day?(date) = @weekdays.include?(date.wday)

  def between(range) = range.select { |date| purchase_day?(date) }

  # O dia de compra mais recente até a data (inclusive), ou nil sem dia cadastrado.
  def on_or_before(date) = (0..6).map { |days| date - days }.find { |day| purchase_day?(day) }

  # O próximo dia de compra a partir da data (inclusive), ou nil sem dia cadastrado.
  def on_or_after(date) = (0..6).map { |days| date + days }.find { |day| purchase_day?(day) }

  # Os dias de compra que cobrem os pedidos: da compra anterior à véspera da primeira entrega até a última entrega.
  def dates
    first, last = OrderLine.where("quantity > 0").pick(Arel.sql("MIN(delivery_date)"), Arel.sql("MAX(delivery_date)"))
    return [] unless first

    start = on_or_before(first - 1) || (first - 1)
    between(start..last)
  end
end
