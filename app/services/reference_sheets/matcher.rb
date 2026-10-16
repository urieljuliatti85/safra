module ReferenceSheets
  # Reconhece o item da planilha: primeiro pelos nomes já ligados (SheetAlias), depois pelo nome do produto, da
  # matéria-prima ou do cliente. "ABÓBORA CUBOS" acha "Abóbora em cubos"; "BAROA DESCASCADA" acha a matéria-prima
  # baroa; "BOM PASTOR" acha o cliente pelo nome curto.
  # Nome que não reconhece devolve nil e vira pergunta na tela de comparação.
  class Matcher
    Match = Data.define(:record, :ignored, :by) # by: :alias | :name

    STOPWORDS = %w[em de da do com].freeze
    # Abreviações das planilhas: "BATATA INTEIRA DESC.", "REPOLHO BR. PICADO".
    ABBREVIATIONS = { "desc" => "descascada", "br" => "branco" }.freeze
    # Como os aprontes e o descascador dizem o estado da matéria-prima ("ALFACE LAVADA", "BATATA BATIDA").
    STATE_WORDS = %w[lavada lavado lavadas lavados descascada descascado descascadas descascados arrumada arrumado
                     batida batido batidas batidos cortada cortado inteira inteiro].freeze

    def self.key(text)
      (OrderImports::NameNormalizer.call(text).split - STOPWORDS).map { |word| ABBREVIATIONS.fetch(word, word) }.join(" ")
    end

    def initialize
      @aliases = SheetAlias.includes(:product, :raw_material).index_by { |a| [ a.target, a.name ] }
      # "Abóbora em lascas (com casca)" também responde por "ABÓBORA EM LASCAS".
      @products = Product.includes(:cut, :raw_material).each_with_object({}) do |product, index|
        index[self.class.key(product.name)] ||= product
        index[self.class.key(product.name.gsub(/\([^)]*\)/, ""))] ||= product
      end
      @raw_materials = RawMaterial.all.each_with_object({}) do |raw_material, index|
        index[self.class.key(raw_material.name)] ||= raw_material
        index[self.class.key(raw_material.code.tr("_", " "))] ||= raw_material
      end
      @customers = Customer.all.each_with_object({}) do |customer, index|
        [ customer.short_name, customer.name, customer.code ].each { |name| index[self.class.key(name)] ||= customer }
      end
      @cache = {}
    end

    def call(label, target)
      @cache[[ label, target ]] ||= lookup(label, target)
    end

    private

    def lookup(label, target)
      key = self.class.key(label)
      if (found = @aliases[[ target, key ]])
        return Match.new(record: found.record, ignored: found.ignored?, by: :alias)
      end

      record = case target
      when "product" then @products[key]
      when "customer" then @customers[key]
      else @raw_materials[key] || @raw_materials[(key.split - STATE_WORDS).join(" ")]
      end
      record && Match.new(record: record, ignored: false, by: :name)
    end
  end
end
