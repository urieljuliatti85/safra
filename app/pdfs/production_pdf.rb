class ProductionPdf < BasePdf
  def initialize(result:, version:)
    super()
    @result = result
    @version = version
  end

  private

  def build
    date = @result.date
    title "Produção · #{Formatting.weekday_date(date)}/#{date.year}",
          [ (@version ? "Versão #{@version.version} enviada em #{@version.sent_at.strftime('%d/%m %H:%M')}" : "Rascunho, ainda não enviado"),
            (@result.delivery_dates.any? ? "Entregas: #{@result.delivery_dates.map { |d| Formatting.weekday_date(d) }.join(', ')}" : nil) ].compact.join(" · ")
    pdf.text "Sem produção neste dia." if @result.items.empty?

    by_sector = @result.items.group_by { |item| item.product.sector }
    Cut::SECTORS.each do |sector|
      items = by_sector[sector]
      next if items.blank?

      section items.first.product.cut.sector_name
      rows = items.map do |item|
        [ item.product.name, Formatting.qty(item.quantity), item.unit,
          item.breakdown.map { |b| "#{b.customer.short_name} #{Formatting.qty(b.quantity)} (#{Formatting.short_date(b.delivery_date)})" }.join(", ") ]
      end
      table [ "Produto", "Qtd.", "Un.", "Quem pediu" ], rows, widths: { 0 => 150, 1 => 45, 2 => 30 }, right: [ 1 ]
    end

    return if @result.aprontes.empty?

    section "Aprontes (caixas para descascar)"
    rows = @result.aprontes.map { |a| [ a.raw_material.name, Formatting.qty(a.kg), a.boxes.to_s ] }
    table [ "Matéria-prima", "kg processado", "Caixas" ], rows, widths: { 1 => 100, 2 => 60 }, right: [ 1, 2 ]
  end
end
