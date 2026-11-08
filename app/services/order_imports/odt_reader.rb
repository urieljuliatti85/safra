require "zip"

module OrderImports
  # Lê um documento ODT em que o cliente cola o pedido como imagem (print de tela, tabela colada, PDF).
  # Devolve as imagens na ordem do documento, cada uma com o cliente e a data que o texto indica
  # ("PEDIDO FÁBRICA TERÇA FEIRA 13/10/26" ou, desde 26/10/2026, "AURORA HOTEL SEGUNDA 26/10", sem o ano; D19).
  # O texto é só uma pista: a data dentro da imagem vale mais.
  class OdtReader
    Entry = Data.define(:index, :filename, :content_type, :data, :hint, :customer_word, :date_hint)

    HEADING = %r{(?:PEDIDO|AURORA)\s+(?<who>[\p{L} ]+?)\s+(?:(?:SEGUNDA|TERÇA|TERCA|QUARTA|QUINTA|SEXTA|S[ÁA]BADO|DOMINGO)(?:\s+FEIRA)?\s+)?(?<date>\d{2}/\d{2}(?:/\d{2,4})?)(?!\d)}i
    TYPES = { ".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".webp" => "image/webp", ".gif" => "image/gif" }.freeze
    MAX_IMAGES = 20
    MAX_IMAGE_BYTES = 10 * 1024 * 1024

    class Unreadable < StandardError; end

    def initialize(path)
      @path = path
    end

    def call
      Zip::File.open(@path) do |zip|
        content = zip.find_entry("content.xml") or raise Unreadable, "O arquivo não parece um documento ODT."
        doc = Nokogiri::XML(content.get_input_stream.read) { |config| config.nonet.noent.strict }
        doc.remove_namespaces!
        entries(zip, doc)
      end
    rescue Zip::Error, Nokogiri::XML::SyntaxError
      raise Unreadable, "Não consegui abrir o documento ODT."
    end

    private

    def entries(zip, doc)
      headings = doc.xpath("//body//p|//body//h").flat_map { |node| node.text.to_enum(:scan, HEADING).map { Regexp.last_match } }
      images = doc.xpath("//frame/image").filter_map { |node| node["href"] }.first(MAX_IMAGES)
      raise Unreadable, "Não achei imagens neste documento." if images.empty?

      images.each_with_index.filter_map do |href, index|
        blob = zip.find_entry(href)
        type = TYPES[File.extname(href).downcase]
        next if blob.nil? || type.nil? || blob.size > MAX_IMAGE_BYTES

        match = headings[index] if headings.size == images.size
        Entry.new(index: index, filename: File.basename(href), content_type: type, data: blob.get_input_stream.read,
                  hint: match && match[0].squeeze(" ").strip, customer_word: match && match[:who].strip, date_hint: match && parse_date(match[:date]))
      end
    end

    # Sem o ano ("26/10"), vale o ano que deixa a data mais perto de hoje.
    def parse_date(text)
      day, month, year = text.split("/").map(&:to_i)
      return Date.new(year < 100 ? 2000 + year : year, month, day) if year

      today = Date.current
      [ today.year - 1, today.year, today.year + 1 ].filter_map { |y| Date.new(y, month, day) rescue nil }.min_by { |date| (date - today).abs }
    rescue Date::Error
      nil
    end
  end
end
