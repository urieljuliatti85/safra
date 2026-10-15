class ProductionPdf < BasePdf
  def initialize(result:, version:, changes: [])
    super()
    @result = result
    @version = version
    @changed = changes.map(&:label)
  end

  private

  def build
    date = @result.date
    subtitle = @result.delivery_dates.any? ? "Entregas: #{@result.delivery_dates.map { |d| Formatting.weekday_date(d) }.join(', ')}" : nil
    header "Produção · #{Formatting.weekday_date(date)}/#{date.year}", subtitle, @version
    pdf.text "Sem produção neste dia." if @result.items.empty?
    if @changed.any?
      pdf.fill_color CHANGE
      pdf.text "Mudou depois do envio: #{@changed.join(', ')}", size: 10, style: :bold
      pdf.fill_color INK
      pdf.move_down 4
    end

    by_sector = @result.items.group_by { |item| item.product.sector }
    Cut::SECTORS.each do |sector|
      items = by_sector[sector]
      next if items.blank?

      section items.first.product.cut.sector_name, "#{items.size} #{items.size == 1 ? 'item' : 'itens'}"
      rows = items.map do |item|
        [ item.product.name, Formatting.qty(item.quantity), item.unit,
          item.breakdown.map { |b| "#{b.customer.short_name} #{Formatting.qty(b.quantity)} (#{Formatting.short_date(b.delivery_date)})" }.join(", ") ]
      end
      flagged = items.each_index.select { |i| @changed.include?(items[i].product.name) }
      table [ "PRODUTO", "QTD.", "UN.", "QUEM PEDIU" ], rows, widths: { 0 => 160, 1 => 55, 2 => 32 }, right: [ 1 ], big: 1, flagged: flagged
    end

    return if @result.aprontes.empty?

    section "Aprontes", "caixas para descascar"
    rows = @result.aprontes.map { |a| [ a.raw_material.name, Formatting.qty(a.kg), a.boxes.to_s ] }
    table [ "MATÉRIA-PRIMA", "KG PROCESSADO", "CAIXAS" ], rows, widths: { 1 => 110, 2 => 70 }, right: [ 1, 2 ], big: 2
  end
end
