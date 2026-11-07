module OrderImports
  # Aplica as AFs conferidas: cada uma no pedido da semana da sua entrega (D3), trocando as linhas daquela AF (D4).
  # Tudo ou nada: se um nome não foi reconhecido, nada é gravado.
  class AfApplier
    Result = Data.define(:errors, :weeks) do
      def ok? = errors.empty?
    end

    def initialize(import:, late_confirmed: false)
      @late_confirmed = late_confirmed
      @import = import
    end

    def call
      afs = @import.payload.fetch("afs")
      unknown = afs.flat_map { |af| af["items"] }.reject { |item| item["product_id"] }.map { |item| item["name"] }.uniq
      return Result.new(errors: unknown.map { |name| "\"#{name}\" não tem produto: cadastre o apelido e importe de novo." }, weeks: []) if unknown.any?

      products = Product.where(id: afs.flat_map { |af| af["items"].map { |item| item["product_id"] } }).index_by(&:id)
      errors = []
      OrderImport.transaction do
        afs.sort_by { |af| af["date"] }.each do |af|
          items = af["items"].map { |item| { product: products.fetch(item["product_id"]), unit: item["unit"], quantity: item["quantity"] } }
          result = SupplyAuthorizationApplier.new(customer: @import.customer, number: af["number"], delivery_date: Date.iso8601(af["date"]),
                                                  items: items, import: @import, late_confirmed: @late_confirmed).call
          errors.concat(result.errors.map { |e| "AF #{af['number']}: #{e}" })
        end
        raise ActiveRecord::Rollback if errors.any?

        @import.update!(status: "applied", applied_at: Time.current)
      end
      Result.new(errors: errors, weeks: afs.map { |af| Date.iso8601(af["date"]).beginning_of_week }.uniq.sort)
    end
  end
end
