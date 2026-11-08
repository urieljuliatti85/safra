module OrderImports
  # Cria um OrderImport do tipo imagem para cada imagem do arquivo: um ODT traz várias (uma por cliente e dia),
  # uma imagem solta vira uma só. O cliente vem do texto do documento quando dá; senão, o que o usuário escolheu.
  class ImageBatch
    def initialize(company:, customer:, path:, filename:, content_type: nil, date: nil)
      @company = company
      @customer = customer
      @path = path
      @filename = filename
      @content_type = content_type
      @date = date
    end

    def call
      ActsAsTenant.with_tenant(@company) do
        batch = SecureRandom.hex(6)
        sources.each_with_index.map do |source, position|
          import = OrderImport.new(
            customer: customer_for(source[:customer_word]), kind: "image", filename: @filename,
            week_start: (source[:date_hint] || @date || Date.current).beginning_of_week,
            payload: { batch: batch, position: position + 1, label: source[:hint] || "Imagem #{position + 1}", hint: source[:hint] }
          )
          import.image.attach(io: StringIO.new(source[:data]), filename: source[:filename], content_type: source[:content_type])
          import.save!
          import
        end
      end
    end

    private

    def sources
      if File.extname(@filename).casecmp(".odt").zero?
        OdtReader.new(@path).call.map do |e|
          { data: e.data, filename: e.filename, content_type: e.content_type, hint: e.hint, customer_word: e.customer_word, date_hint: e.date_hint }
        end
      else
        type = @content_type.presence || Marcel::MimeType.for(Pathname.new(@path), name: @filename)
        raise OdtReader::Unreadable, "Formato não aceito. Envie um ODT ou uma imagem PNG, JPEG, WebP ou GIF." unless OrderImport::IMAGE_TYPES.include?(type)

        [ { data: File.binread(@path), filename: @filename, content_type: type } ]
      end
    end

    def customer_for(word)
      return @customer if word.blank?

      # Letra repetida não conta: o título de 26/10 escreve "MOLINARI" para a Aurora Mollinari (D19).
      token = NameNormalizer.call(word).squeeze
      matches = Customer.all.select { |c| NameNormalizer.call(c.name).squeeze.include?(token) }
      matches.one? ? matches.first : @customer
    end
  end
end
