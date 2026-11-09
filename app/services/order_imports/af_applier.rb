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

      errors = []
      OrderImport.transaction do
        appliers(afs).each do |af, applier|
          errors.concat(applier.call.errors.map { |e| "AF #{af['number']}: #{e}" })
        end
        raise ActiveRecord::Rollback if errors.any?

        @import.update!(status: "applied", applied_at: Time.current)
      end
      Result.new(errors: errors, weeks: afs.map { |af| Date.iso8601(af["date"]).beginning_of_week }.uniq.sort)
    end

    # ["AF 0009100646: Chuchu em 03/11", ...]: o que pediria a confirmação das 48 h, sem gravar nada.
    # AF nova ou igual à que já estava não pede; AF com nome sem produto fica de fora (não dá para aplicar).
    def late_alterations
      afs = @import.payload.fetch("afs").select { |af| af["items"].all? { |item| item["product_id"] } }
      appliers(afs).flat_map { |af, applier| applier.late_alterations.map { |label| "AF #{af['number']}: #{label}" } }
    end

    private

    def appliers(afs)
      products = Product.where(id: afs.flat_map { |af| af["items"].map { |item| item["product_id"] } }).index_by(&:id)
      afs.sort_by { |af| af["date"] }.map do |af|
        items = af["items"].map { |item| { product: products.fetch(item["product_id"]), unit: item["unit"], quantity: item["quantity"] } }
        # O PDF diz o tipo: AF nova é pedido novo; ALTERAÇÃO troca a lista da AF pelo novo total (R1.27, R1.31).
        [ af, SupplyAuthorizationApplier.new(customer: @import.customer, number: af["number"], delivery_date: Date.iso8601(af["date"]),
                                             items: items, import: @import, late_confirmed: @late_confirmed,
                                             entry_type: af["alteration"] ? "alteration" : "new") ]
      end
    end
  end
end
