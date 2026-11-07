require "pdf-reader"

module OrderImports
  # Lê o PDF de Autorizações de Fornecimento (AF) da Nutrir (R1.2, R1.5; D2): o do mês, com uma AF por página, e o
  # da alteração, que chega com o mesmo número da AF e a lista inteira (R1.27). Só extrai; quem grava é o AfApplier.
  class AfReader
    Unreadable = Class.new(StandardError)
    Item = Data.define(:name, :unit, :quantity, :changed)
    Af = Data.define(:number, :delivery_date, :alteration, :unit_code, :items)

    NUMBER = /(?:\bAF:|Autoriza[çc][ãa]o de Fornecimento:)\s*(\d{6,})/i
    DATE = %r{Data de Entrega:\s*(\d{2}/\d{2}/\d{4})}i
    UNIT_CODE = /(?:C[óo]digo:|Unidade Destino:)\s*(\d+)/i
    # "CENOURA PROC CUBO 10MM KG   44,000   7,80000 ..." (mês) ou "* CHUCHU ... KG - KG   330,000   5,90 ..." (alteração).
    ITEM = /\A\s*(\*)?\s*(\S.*?)\s+(?:(KG|UN)(?:\s+-\s+(?:KG|UN))?\s+)?(\d{1,3}(?:\.\d{3})*,\d{3})\s+\d[\d.,]*\s+\S/

    def self.call(path) = new.parse(read_pages(path))

    def self.read_pages(path)
      PDF::Reader.new(path).pages.map(&:text)
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
      raise Unreadable, "Não consegui ler este PDF."
    end

    # pages: o texto de cada página. Cada página com número de AF e data de entrega vira uma AF.
    def parse(pages)
      afs = pages.filter_map { |text| parse_page(text) }
      raise Unreadable, "Não achei nenhuma AF com data de entrega neste PDF." if afs.empty?

      afs
    end

    private

    def parse_page(text)
      number = text[NUMBER, 1]
      date = text[DATE, 1]
      return unless number && date

      Af.new(number: number, delivery_date: Date.strptime(date, "%d/%m/%Y"), alteration: text.match?(/ALTERA[ÇC][ÃA]O/i),
             unit_code: text[UNIT_CODE, 1], items: text.lines.filter_map { |line| parse_item(line) })
    end

    def parse_item(line)
      match = line.match(ITEM)
      return unless match

      name = match[2].strip
      unit = match[3]&.downcase || (name.match?(/-UN\z/i) ? "un" : "kg")
      Item.new(name: name, unit: unit, quantity: BigDecimal(match[4].delete(".").tr(",", ".")), changed: match[1].present?)
    end
  end
end
