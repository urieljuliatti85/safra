module OrderImports
  # Lê o PDF de AFs e guarda num OrderImport (tipo "af") para conferir antes de aplicar (D2). O PDF do mês cobre
  # várias semanas: cada AF vai para o pedido da semana da sua entrega na hora de aplicar (D3).
  class AfImporter
    def initialize(company:, customer:, path:, filename:)
      @company = company
      @customer = customer
      @path = path
      @filename = filename
    end

    def call
      ActsAsTenant.with_tenant(@company) do
        afs = AfReader.call(@path)
        matcher = Matcher.new(customer: @customer)
        OrderImport.create!(
          customer: @customer, filename: @filename, kind: "af", week_start: afs.map(&:delivery_date).min.beginning_of_week,
          payload: { afs: afs.map { |af| serialize(af, matcher) }, errors: errors(afs) }
        )
      end
    end

    private

    def serialize(af, matcher)
      { number: af.number, date: af.delivery_date.iso8601, alteration: af.alteration, unit_code: af.unit_code,
        items: af.items.map do |item|
          match = matcher.call(item.name)
          { name: item.name, unit: item.unit, quantity: item.quantity.to_s("F"), changed: item.changed, product_id: match&.product&.id }
        end }
    end

    def errors(afs)
      errors = []
      errors << "#{@customer.short_name} não está marcado como cliente de pedido mensal no cadastro." unless @customer.monthly_orders?
      codes = afs.map(&:unit_code).compact.uniq
      errors << "O PDF é da unidade #{codes.join(', ')}." if codes.any? && codes != [ "4471" ] && @customer.code == "nutrir"
      errors
    end
  end
end
