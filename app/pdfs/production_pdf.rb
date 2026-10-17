# Duas leituras do mesmo dia: o escritório imprime o cálculo atual (com o que mudou desde o envio marcado em vermelho);
# os setores imprimem a versão enviada (notice: aviso em vermelho, como alteração ainda não enviada ou versão substituída).
class ProductionPdf < BasePdf
  # sector: visão dos setores (só o enviado); sector_label: a folha é de um setor só (ou só os aprontes).
  def initialize(result:, version:, changes: [], sector: false, notice: nil, sector_label: nil)
    super()
    @result = result
    @sector_label = sector_label
    @version = version
    @changed = changes.map(&:label)
    @sector = sector
    @notice = notice
  end

  private

  def build
    date = @result.date
    deliveries = "Entregas: #{@result.delivery_dates.map { |d| Formatting.weekday_date(d) }.join(', ')}" if @result.delivery_dates.any?
    subtitle = [ @sector_label && "Setor: #{@sector_label}", deliveries ].compact.join(" · ").presence
    header "Produção · #{Formatting.weekday_date(date)}/#{date.year}", subtitle, @version, changed: @changed.any?
    pdf.text(@sector && @version.nil? ? "O escritório ainda não enviou a produção deste dia." : "Sem produção neste dia.") if @result.items.empty? && @result.aprontes.empty?
    if @notice
      pdf.fill_color CHANGE
      pdf.text @notice, size: 10, style: :bold
      pdf.fill_color INK
      pdf.move_down 4
    end
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
