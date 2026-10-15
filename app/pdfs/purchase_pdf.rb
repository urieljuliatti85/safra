class PurchasePdf < BasePdf
  def initialize(date:, suppliers:, version:)
    super()
    @date = date
    @suppliers = suppliers
    @version = version
  end

  private

  def build
    title "Compras CEASA · #{Formatting.weekday_date(@date)}/#{@date.year}",
          @version ? "Versão #{@version.version} enviada em #{@version.sent_at.strftime('%d/%m %H:%M')}" : "Rascunho, ainda não enviado"
    pdf.text "Nada a comprar neste dia." if @suppliers.empty?
    @suppliers.each do |supplier, needs|
      section supplier
      rows = needs.map do |n|
        [ n.raw_material.name, "#{Formatting.qty(n.kg)} #{n.unit}", n.stock_kg.positive? ? "#{Formatting.qty(n.stock_kg)} kg" : "-", Formatting.need_text(n) ]
      end
      table [ "Matéria-prima", "Necessidade", "Estoque", "Comprar" ], rows, widths: { 1 => 100, 2 => 80, 3 => 90 }, right: [ 1, 2, 3 ]
    end
  end
end
