module OrderImports
  # Reconhece o nome do produto como o cliente o escreve: primeiro pelos apelidos já confirmados desse cliente,
  # depois pelo nome do produto. Nome novo devolve nil e vira pergunta na conferência.
  class Matcher
    Match = Data.define(:product, :by) # by: :alias | :name

    def initialize(customer:)
      @aliases = customer.aliases.includes(:product).index_by { |a| NameNormalizer.call(a.name_in_order) }
      @products = Product.all.index_by { |p| NameNormalizer.call(p.name) }
    end

    def call(name)
      key = NameNormalizer.call(name)
      if (found = @aliases[key])
        Match.new(product: found.product, by: :alias)
      elsif (product = @products[key])
        Match.new(product: product, by: :name)
      end
    end
  end
end
