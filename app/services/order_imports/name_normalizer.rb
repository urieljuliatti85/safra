module OrderImports
  # "Batata Inglesa  Cubos Pequenos" e "BATATA INGLESA CUBOS PEQUENOS" são o mesmo nome no pedido.
  module NameNormalizer
    module_function

    def call(text)
      I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
    end
  end
end
